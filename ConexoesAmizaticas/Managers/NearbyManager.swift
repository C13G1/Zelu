//
//  NearbyManager.swift
//  ConexoesAmizaticas
//
//  Created by Enzo Ferroni on 09/06/26.
//
//  Discovers every nearby app user over BLE (not just one) and exchanges profiles so the
//  "Pessoas por perto" grid can show each person's name and photo, AirDrop-style.
//
//  Unlike `BLEManager` — which auto-pairs with a single closest peer and then stops — this manager
//  keeps a live L2CAP link to each discovered peer for as long as the grid is on screen, exchanging
//  full profiles over each link. One link per pair is guaranteed by a stable key tie-breaker.
//

import Foundation
import CoreBluetooth
import UIKit

/// A person discovered nearby, surfaced to the grid UI.
struct NearbyPerson: Identifiable, Equatable {
    let user: User
    var rssi: Int
    var lastSeen: Date

    var id: UUID { user.id }

    static func == (lhs: NearbyPerson, rhs: NearbyPerson) -> Bool {
        lhs.user.id == rhs.user.id && lhs.rssi == rhs.rssi
    }
}

@Observable
final class NearbyManager: NSObject {

    /// Emitted whenever the set of nearby people changes (added, profile arrived, or left).
    private(set) var people: [NearbyPerson] = []

    /// Our own profile, served to peers that connect to us.
    let profile: User

    // Shared identifiers — must match the peer app exactly.
    private let serviceID = CBUUID(string: "451A3F17-0062-41E1-82CC-98496CDA05FB")
    private let portCharacteristicID = CBUUID(string: "B2C20EFB-B20F-4F0D-B708-4EA408F2C500")

    private var centralManager: CBCentralManager!
    private var peripheralManager: CBPeripheralManager!

    /// Our published L2CAP PSM (peripheral side). Served from the read characteristic.
    private var psm: CBL2CAPPSM?
    /// Stable for the whole discovery session so both sides of a pair make the same tie-breaker call.
    private let advertisingKey = Int.random(in: 1...100_000_000)

    /// One live link per connected peer, keyed by the peer's `User.id` once its profile arrives.
    private var links: [ObjectIdentifier: Link] = [:]    // keyed by stream identity for fast demux
    private var allLinks: [Link] = []

    /// Peripherals we're already connecting to / connected to (central side), to avoid duplicates.
    private var connectingPeripherals: Set<UUID> = []

    /// Max bytes read from a stream per pass.
    private static let bufferSize = 1024
    /// Drop people we haven't re-heard from in this long.
    private static let staleAfter: TimeInterval = 12
    private var pruneTimer: Timer?

    init(profile: User) {
        self.profile = profile
        super.init()
    }

    // MARK: - Lifecycle

    func start() {
        print("nearby start")
        centralManager = CBCentralManager(delegate: self, queue: nil)
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        pruneTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.pruneStale()
        }
    }

    func stop() {
        print("nearby stop")
        pruneTimer?.invalidate()
        pruneTimer = nil
        for link in allLinks { closeLink(link) }
        allLinks.removeAll()
        links.removeAll()
        connectingPeripherals.removeAll()
        centralManager?.stopScan()
        centralManager?.delegate = nil
        centralManager = nil
        peripheralManager?.stopAdvertising()
        peripheralManager?.delegate = nil
        peripheralManager = nil
        psm = nil
        people.removeAll()
    }

    // MARK: - Grid state

    /// Inserts or refreshes a discovered person and re-sorts by signal strength (closest first).
    private func upsert(_ user: User, rssi: Int) {
        if let index = people.firstIndex(where: { $0.user.id == user.id }) {
            people[index].lastSeen = .now
            if rssi != 0 { people[index].rssi = rssi }
        } else {
            people.append(NearbyPerson(user: user, rssi: rssi, lastSeen: .now))
        }
        people.sort { $0.rssi > $1.rssi }
    }

    private func touch(userID: UUID, rssi: Int) {
        guard let index = people.firstIndex(where: { $0.user.id == userID }) else { return }
        people[index].lastSeen = .now
        if rssi != 0 { people[index].rssi = rssi }
    }

    private func remove(userID: UUID?) {
        guard let userID else { return }
        people.removeAll { $0.user.id == userID }
    }

    private func pruneStale() {
        let cutoff = Date.now.addingTimeInterval(-NearbyManager.staleAfter)
        people.removeAll { $0.lastSeen < cutoff }
    }

    #if DEBUG
    /// Seeds the grid with fake people so the UI can be exercised without a room full of devices.
    /// Their `lastSeen` is set far in the future so the prune timer never removes them.
    func injectMockPeople() {
        let picture = UIImage(named: "defaultPicture")?.jpegData(compressionQuality: 0.8) ?? Data()
        let names = ["Osmar", "Ed Sheeran", "Laura", "Juliana", "Thais"]
        for (index, name) in names.enumerated() {
            let user = User(name: name, profilePicture: picture)
            guard !people.contains(where: { $0.user.name == name }) else { continue }
            people.append(NearbyPerson(user: user, rssi: -40 - index * 5, lastSeen: .distantFuture))
        }
        people.sort { $0.rssi > $1.rssi }
    }
    #endif

    // MARK: - Per-peer link

    /// Holds the streams and receive buffer for one peer connection.
    private final class Link {
        var channel: CBL2CAPChannel?
        var input: InputStream?
        var output: OutputStream?
        var rx = Data()
        var tx = Data()
        var sent = 0
        var queuedProfile = false
        /// Set once the peer's profile is decoded; used to route disconnects to grid removal.
        var userID: UUID?
        weak var peripheral: CBPeripheral?   // central side only
    }

    private func setupLink(for channel: CBL2CAPChannel, peripheral: CBPeripheral?) {
        guard let input = channel.inputStream, let output = channel.outputStream else { return }
        let link = Link()
        link.channel = channel
        link.input = input
        link.output = output
        link.peripheral = peripheral
        allLinks.append(link)
        links[ObjectIdentifier(input)] = link
        links[ObjectIdentifier(output)] = link
        input.delegate = self
        output.delegate = self
        input.schedule(in: .main, forMode: .default)
        output.schedule(in: .main, forMode: .default)
        output.open()
        input.open()
    }

    private func closeLink(_ link: Link) {
        link.input?.delegate = nil
        link.output?.delegate = nil
        link.input?.close()
        link.output?.close()
        link.input?.remove(from: .main, forMode: .default)
        link.output?.remove(from: .main, forMode: .default)
        if let input = link.input { links.removeValue(forKey: ObjectIdentifier(input)) }
        if let output = link.output { links.removeValue(forKey: ObjectIdentifier(output)) }
        if let peripheral = link.peripheral {
            connectingPeripherals.remove(peripheral.identifier)
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        allLinks.removeAll { $0 === link }
    }

    private func tearDownLink(_ link: Link) {
        remove(userID: link.userID)
        closeLink(link)
    }

    // MARK: - Sending our profile

    private func queueProfile(on link: Link) {
        guard !link.queuedProfile else { return }
        let picture: Data
        if let image = UIImage(data: profile.profilePicture),
           let compressed = image.preparingThumbnail(of: CGSize(width: 256, height: 256))?
               .jpegData(compressionQuality: 0.7) {
            picture = compressed
        } else {
            picture = profile.profilePicture
        }
        let dto = UserDTO(name: profile.name, profilePicture: picture, id: profile.id)
        guard let json = try? JSONEncoder().encode(dto) else { return }
        link.queuedProfile = true
        var length = UInt32(json.count).bigEndian
        link.tx.append(Data(bytes: &length, count: 4))
        link.tx.append(json)
        flush(link)
    }

    private func flush(_ link: Link) {
        guard let output = link.output, link.sent < link.tx.count else { return }
        while link.sent < link.tx.count, output.hasSpaceAvailable {
            let remaining = link.tx.count - link.sent
            let written = link.tx.withUnsafeBytes { raw -> Int in
                guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return -1 }
                return output.write(base + link.sent, maxLength: remaining)
            }
            guard written > 0 else { break }
            link.sent += written
        }
    }

    // MARK: - Receiving a peer profile

    private func receive(on link: Link) {
        guard let input = link.input else { return }
        var buffer = [UInt8](repeating: 0, count: NearbyManager.bufferSize)
        while input.hasBytesAvailable {
            let read = input.read(&buffer, maxLength: NearbyManager.bufferSize)
            if read > 0 { link.rx.append(contentsOf: buffer.prefix(read)) }
        }
        decode(on: link)
    }

    private func decode(on link: Link) {
        guard link.userID == nil else { return }   // profile already decoded for this link
        guard link.rx.count >= 4 else { return }
        let expected = link.rx.withUnsafeBytes { Int(UInt32(bigEndian: $0.load(as: UInt32.self))) }
        guard link.rx.count >= expected + 4 else { return }
        let json = link.rx.subdata(in: 4..<expected + 4)
        guard let dto = try? JSONDecoder().decode(UserDTO.self, from: json) else { return }
        let user = User(name: dto.name, profilePicture: dto.profilePicture, id: dto.id)
        link.userID = user.id
        link.rx.removeSubrange(0..<expected + 4)
        print("nearby decoded: \(user.name)")
        upsert(user, rssi: 0)
    }
}

// MARK: - CBCentralManagerDelegate

extension NearbyManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else { return }
        central.scanForPeripherals(withServices: [serviceID],
                                   options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi: NSNumber) {
        guard let keyString = advertisementData[CBAdvertisementDataLocalNameKey] as? String,
              let peerKey = Int(keyString) else { return }

        // Tie-breaker: the lower key connects, the higher key waits to be connected to — so each pair
        // forms exactly one link. (Equal keys are astronomically unlikely.)
        guard peerKey < advertisingKey else { return }
        guard !connectingPeripherals.contains(peripheral.identifier) else { return }

        connectingPeripherals.insert(peripheral.identifier)
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectingPeripherals.remove(peripheral.identifier)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectingPeripherals.remove(peripheral.identifier)
        if let link = allLinks.first(where: { $0.peripheral?.identifier == peripheral.identifier }) {
            tearDownLink(link)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([serviceID])
    }
}

// MARK: - CBPeripheralDelegate (central side: read PSM, open channel)

extension NearbyManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {}

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics([portCharacteristicID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics where characteristic.uuid == portCharacteristicID {
            peripheral.readValue(for: characteristic)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil,
              characteristic.uuid == portCharacteristicID,
              let data = characteristic.value,
              data.count >= MemoryLayout<CBL2CAPPSM>.size else { return }
        let peerPSM = data.withUnsafeBytes { $0.load(as: CBL2CAPPSM.self) }
        peripheral.openL2CAPChannel(peerPSM)
    }

    func peripheral(_ peripheral: CBPeripheral, didOpen channel: CBL2CAPChannel?, error: Error?) {
        guard error == nil, let channel else { return }
        setupLink(for: channel, peripheral: peripheral)
    }
}

// MARK: - CBPeripheralManagerDelegate (advertise, publish L2CAP, serve PSM)

extension NearbyManager: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        guard peripheral.state == .poweredOn else { return }
        let characteristic = CBMutableCharacteristic(type: portCharacteristicID,
                                                     properties: [.read], value: nil,
                                                     permissions: [.readable])
        let service = CBMutableService(type: serviceID, primary: true)
        service.characteristics = [characteristic]
        peripheral.add(service)
        peripheral.publishL2CAPChannel(withEncryption: false)
        peripheral.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [serviceID],
            CBAdvertisementDataLocalNameKey: "\(advertisingKey)"
        ])
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didPublishL2CAPChannel PSM: CBL2CAPPSM, error: Error?) {
        guard error == nil else { return }
        psm = PSM
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        guard request.characteristic.uuid == portCharacteristicID, var value = psm else {
            peripheral.respond(to: request, withResult: .attributeNotFound)
            return
        }
        request.value = Data(bytes: &value, count: MemoryLayout<CBL2CAPPSM>.size)
        peripheral.respond(to: request, withResult: .success)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didOpen channel: CBL2CAPChannel?, error: Error?) {
        guard error == nil, let channel else { return }
        setupLink(for: channel, peripheral: nil)
    }
}

// MARK: - StreamDelegate (per-link demux)

extension NearbyManager: StreamDelegate {
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        guard let link = links[ObjectIdentifier(aStream)] else { return }
        switch eventCode {
        case .hasBytesAvailable:
            receive(on: link)
        case .openCompleted, .hasSpaceAvailable:
            if aStream === link.output {
                queueProfile(on: link)
                flush(link)
            }
        case .errorOccurred, .endEncountered:
            tearDownLink(link)
        default:
            break
        }
    }
}
