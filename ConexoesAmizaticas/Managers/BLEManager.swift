//
//  BLEManager.swift
 //  ConexoesAmizaticas
//
//  Created by Thomas Pinheiro Grandin on 15/05/26.
//

import Foundation
import CoreBluetooth
import UIKit
import SwiftUI

/// `BLEManager` acts as both a Central and a Peripheral. It broadcasts the user's profile and scans for other users
/// broadcasting the specific app service. When it discovers users, it sends them to the `BLEViewModel`
class BLEManager: NSObject, CBCentralManagerDelegate, CBPeripheralManagerDelegate, CBPeripheralDelegate {

    /// A closure triggered when a complete user profile is successfully received over the BLE stream.
    var onFriendFound: ((String) -> Void)?

    var centralManager: CBCentralManager!
    var peripheralManager: CBPeripheralManager!
    
    let serviceID: CBUUID = CBUUID(string: "451A3F17-0062-41E1-82CC-98496CDA05FB")
    let portCharacteristicID: CBUUID = CBUUID(string: "B2C20EFB-B20F-4F0D-B708-4EA408F2C500")
    let advertisingKey: Int = Int.random(in: 1...100_000_000)
    var foundUsers: [String] = []
    let btThreshold: Int = -50
    
    /// The profile of the current user that will be transmitted to peers.
    let profile: User
    private var didSendProfile = false

    init(profile: User) {
        self.profile = profile
        super.init()
    }

    /// Initializes the Central and Peripheral managers and starts scanning/advertising.
    func startBLE() {
        print("start ble")
        stopBLE()
        didSendProfile = false
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
        self.peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }

    /// Stops all ongoing BLE scanning and advertising activities.
    func stopBLE() {
        print("stop ble")
        centralManager?.stopScan()
        centralManager?.delegate = nil
        peripheralManager?.stopAdvertising()
        peripheralManager?.delegate = nil
    }

    // MARK: - CoreBluetooth Delegates
    // (Standard CBCentralManager, CBPeripheralManager, and CBPeripheral delegate methods)
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            print("central power on")
            centralManager.scanForPeripherals(withServices: [serviceID], options: nil)
        } else {
            print("central state: \(central.state.rawValue)")
        }
    }
    

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
        
        print("Found friend on BLE")
        guard rssi.intValue >= btThreshold else {
            print("user muito longe")
            return
        }
        guard let userID = advertisementData[CBAdvertisementDataLocalNameKey] as? String else {
            print("problema ao decodificar id: \(advertisementData[CBAdvertisementDataLocalNameKey])")
            return
        }
        
        print("verified friend: \(userID)!")
        if let onFriendFound = onFriendFound {
            onFriendFound(userID)
        }
        else {
            print("no function for finding friends")
        }
        stopBLE()
    }

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
            print("peripheral powered on")
            let service = CBMutableService(type: serviceID, primary: true)
            peripheral.add(service)
            peripheral.startAdvertising([
                CBAdvertisementDataServiceUUIDsKey: [serviceID],
                CBAdvertisementDataLocalNameKey: String(profile.id.uuidString.prefix(8))
            ])
        } else {
            print("peripheral state: \(peripheral.state.rawValue)")
        }
    }
}
