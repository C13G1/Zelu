//
//  NearbyProximityScanner.swift
//  ConexoesAmizaticas
//
//  Created by Enzo Ferroni on 10/06/26.
//

import CoreBluetooth

/// Estimates how far each nearby person is, using the strength of their Bluetooth signal.
///
/// MultipeerConnectivity discovers and connects people but says nothing about distance, so this
/// scanner runs in parallel: every device announces its user id over Bluetooth and listens for the
/// announcements of the others. The strength of each received announcement (RSSI) gives a rough
/// distance in meters, which `NearbyManager` uses to place the person on a ring and to hide
/// whoever is too far away.
final class NearbyProximityScanner: NSObject {

    /// Called on the main thread whenever a fresh distance estimate arrives. Delivers the
    /// announced user id (it can arrive cut short, see `peripheralManagerDidUpdateState`) and the
    /// estimated distance in meters.
    var onDistanceReading: ((_ userID: String, _ meters: Double) -> Void)?

    /// Service announced over Bluetooth. Exclusive to this scanner, so it never interferes with
    /// the meeting screen pairing, which uses a different one.
    private static let serviceID = CBUUID(string: "7E4C1B9A-3D52-4F8E-9C61-2A0B8D5E7F33")

    /// Signal strength expected at exactly 1 meter, used to turn signal into meters. To calibrate:
    /// put two phones 1 meter apart and adjust until the app shows about 1 meter.
    private static let rssiAtOneMeter: Double = -59

    /// How fast the signal fades with distance: 2 in open space, 3 to 4 with walls, pockets and
    /// people in between. Raising it makes everyone look closer.
    private static let signalFade: Double = 2.5

    /// Weight of each new reading against the previous ones (0 = frozen, 1 = raw reading). The
    /// signal jumps around a lot, so a low value keeps people from flickering between rings.
    private static let smoothing: Double = 0.3

    private let ownID: String
    private var central: CBCentralManager?
    private var advertiser: CBPeripheralManager?
    /// Smoothed signal strength per announced user id.
    private var smoothedRSSI: [String: Double] = [:]

    init(ownID: String) {
        self.ownID = ownID
        super.init()
    }

    /// Starts announcing this device and measuring everyone else. Safe to call repeatedly.
    func start() {
        guard central == nil else { return }
        central = CBCentralManager(delegate: self, queue: nil)
        advertiser = CBPeripheralManager(delegate: self, queue: nil)
    }

    /// Stops announcing and measuring.
    func stop() {
        central?.stopScan()
        central?.delegate = nil
        central = nil
        advertiser?.stopAdvertising()
        advertiser?.delegate = nil
        advertiser = nil
        smoothedRSSI.removeAll()
    }
}

extension NearbyProximityScanner: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else { return }
        // Repeated discoveries of the same device are wanted here: each one is a fresh reading.
        central.scanForPeripherals(withServices: [Self.serviceID],
                                   options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi: NSNumber) {
        // 127 is CoreBluetooth's marker for "signal unknown".
        guard rssi.intValue != 127,
              let userID = advertisementData[CBAdvertisementDataLocalNameKey] as? String,
              !userID.isEmpty
        else { return }

        let smoothed = (smoothedRSSI[userID] ?? rssi.doubleValue) * (1 - Self.smoothing)
            + rssi.doubleValue * Self.smoothing
        smoothedRSSI[userID] = smoothed

        // Standard conversion of signal strength into meters. Rough by nature.
        let meters = pow(10, (Self.rssiAtOneMeter - smoothed) / (10 * Self.signalFade))
        onDistanceReading?(userID, meters)
    }
}

extension NearbyProximityScanner: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        guard peripheral.state == .poweredOn else { return }
        // The id may not fit whole in the announcement (Bluetooth cuts the name at about 28
        // characters), so the receiver matches it as the beginning of the full id.
        peripheral.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [Self.serviceID],
            CBAdvertisementDataLocalNameKey: ownID
        ])
    }
}
