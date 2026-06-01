//
//  ProximityNotifier.swift
//  ConexoesAmizaticas
//
//  Created by Enzo Ferroni on 27/05/26.
//

import Foundation
import UserNotifications
import CoreBluetooth
import UIKit

/// Detects nearby Zelu users while the app is not in the foreground and fires a local notification
/// inviting the user to open the app and register the encounter.
///
/// `ProximityNotifier` is a singleton because Core Bluetooth restoration requires a stable
/// `CBCentralManager` identifier across launches. It only emits a notification when the app is
/// in the background or inactive and respects a cooldown to avoid spam.
class ProximityNotifier: NSObject, CBCentralManagerDelegate {
    /// The shared instance bound to the Core Bluetooth restoration identifier.
    static let shared = ProximityNotifier()

    private var centralManager: CBCentralManager?
    private let serviceID = CBUUID(string: "451A3F17-0062-41E1-82CC-98496CDA05FB")
    private var lastNotificationDate: Date?
    private let cooldown: TimeInterval = 5 * 60

    private override init() { super.init() }

    /// Boots the underlying `CBCentralManager` with state restoration. Safe to call multiple times.
    func start() {
        guard centralManager == nil else { return }
        centralManager = CBCentralManager(
            delegate: self,
            queue: nil,
            options: [CBCentralManagerOptionRestoreIdentifierKey: "com.conexoesamizaticas.proximity"]
        )
    }
    
    func cancel() {
        centralManager = nil
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            central.scanForPeripherals(
                withServices: [serviceID],
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
            )
        }
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi: NSNumber
    ) {
        guard UIApplication.shared.applicationState != .active else { return }
        if let last = lastNotificationDate, Date().timeIntervalSince(last) < cooldown { return }
        lastNotificationDate = Date()

        let content = UNMutableNotificationContent()
        content.title = "Alguém com Zelu está por perto!"
        content.body = "Abra o app para registrar um encontro com seu amigo."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "proximity_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)

        // reinicia o scan depois do cooldown de 5 min, evita spam
        central.stopScan()
        DispatchQueue.main.asyncAfter(deadline: .now() + cooldown) { [weak self] in
            guard let self, central.state == .poweredOn else { return }
            central.scanForPeripherals(
                withServices: [self.serviceID],
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
            )
        }
    }
}
