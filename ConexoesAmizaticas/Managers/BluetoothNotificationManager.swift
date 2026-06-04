//
//  BluetoothNotificationManager.swift
//  ConexoesAmizaticas
//
//  Created by Jonas Fernando Nascimento Melo on 02/06/26.
//

import Foundation
import CoreBluetooth
import SwiftUI
import Combine

@Observable
class BluetoothNotificationManager: NSObject, ObservableObject, CBCentralManagerDelegate {
    private var centralManager: CBCentralManager?

    var isBluetoothReady = false
    var authorizationState: CBManagerAuthorization = CBCentralManager.authorization
    var managerState: CBManagerState = .unknown

    /// High-level access state the UI uses to decide which Bluetooth overlay (if any) to present.
    enum AccessState: Equatable {
        /// Authorized and powered on — BLE can run, no overlay.
        case ready
        /// The user has never been asked — show the first-time permission overlay.
        case needsPermission
        /// Permission denied/restricted or Bluetooth powered off — show the disabled overlay.
        case unavailable
    }

    /// Maps the raw authorization + power state into the overlay-driving `AccessState`.
    ///
    /// While authorization is granted but the live power state is still `.unknown` (the central
    /// manager has not reported in yet), we optimistically report `.ready` so the disabled overlay
    /// never flashes during the brief boot window.
    var accessState: AccessState {
        switch authorizationState {
        case .notDetermined:
            return .needsPermission
        case .allowedAlways:
            switch managerState {
            case .poweredOff, .unauthorized, .unsupported, .resetting:
                return .unavailable
            default:
                return .ready
            }
        default:
            return .unavailable
        }
    }

    override init() {
        super.init()
    }

    /// Re-reads the system authorization status without instantiating a manager, so we can decide
    /// what to show before triggering the native permission prompt.
    func refreshAuthorization() {
        authorizationState = CBCentralManager.authorization
    }

    /// Instantiates the central manager. The first time this runs (while `.notDetermined`) iOS shows
    /// the native permission prompt; afterwards it lets us observe the live power state.
    func requestBluetoothPermission() {
        guard centralManager == nil else { return }
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        authorizationState = CBCentralManager.authorization
        managerState = central.state
        isBluetoothReady = (authorizationState == .allowedAlways && central.state == .poweredOn)
    }
}
