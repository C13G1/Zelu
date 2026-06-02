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
    var authorizationState: CBManagerAuthorization = .notDetermined
    
    override init() {
        super.init()
    }
    
    func requestBluetoothPermission() {
        guard centralManager == nil else { return }
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        authorizationState = CBCentralManager.authorization
        
        switch authorizationState {
        case .notDetermined:
            isBluetoothReady = false
        case .restricted:
            isBluetoothReady = false
        case .denied:
            isBluetoothReady = false
        case .allowedAlways:
            isBluetoothReady = true
        default:
            isBluetoothReady = false
        }
    }
}
    
