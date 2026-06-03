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
    let btThreshold: Int = -80
    
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
        guard let keyString = advertisementData[CBAdvertisementDataLocalNameKey] as? String,
              let peripheralKey = Int(keyString) else { return }

        // Tie-breaker to decide which device acts as the central and which acts as the peripheral
        if peripheralKey > advertisingKey {
            print("virou peripheral")
            centralManager.stopScan()
            peripheralManager.publishL2CAPChannel(withEncryption: false)
        } else {
            print("virou central")
            centralManager.stopScan()
            centralManager.connect(peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("central connected")
        peripheral.delegate = self
        peripheral.discoverServices([serviceID])
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Erro ao descobrir serviços: \(error.localizedDescription)")
            return
        }
        guard let services = peripheral.services else { return }
        print("found services")
        for service in services {
            peripheral.discoverCharacteristics([portCharacteristicID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: (any Error)?) {
        guard let characteristics = service.characteristics else { return }
        print("discovered characteristics")
        for characteristic in characteristics {
            if characteristic.uuid == portCharacteristicID {
                peripheral.readValue(for: characteristic)
            }
        }
    }


//
//    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
//        
//        print("Found friend on BLE")
//        guard rssi.intValue >= btThreshold else {
//            print("user muito longe")
//            return
//        }
//        guard let userID = advertisementData[CBAdvertisementDataLocalNameKey] as? String else {
//            print("problema ao decodificar id: \(advertisementData[CBAdvertisementDataLocalNameKey])")
//            return
//        }
//        
//        print("verified friend: \(userID)!")
//        if let onFriendFound = onFriendFound {
//            onFriendFound(userID)
//        }
//        else {
//            print("no function for finding friends")
//        }
//    }
//
//    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
//        if peripheral.state == .poweredOn {
//            print("peripheral powered on")
//            let service = CBMutableService(type: serviceID, primary: true)
//            peripheral.add(service)
//            peripheral.startAdvertising([
//                CBAdvertisementDataServiceUUIDsKey: [serviceID],
//                CBAdvertisementDataLocalNameKey: profile.id.uuidString
//            ])
//        } else {
//            print("peripheral state: \(peripheral.state.rawValue)")
//        }
//    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
            print("peripheral powered on")
            let characteristic = CBMutableCharacteristic(
                type: portCharacteristicID,
                properties: [.read],
                value: nil,
                permissions: [.readable]
            )
            let service = CBMutableService(type: serviceID, primary: true)
            service.characteristics = [characteristic]
            peripheral.add(service)
            peripheral.startAdvertising([
                CBAdvertisementDataServiceUUIDsKey: [serviceID],
                CBAdvertisementDataLocalNameKey: "\(advertisingKey)"
            ])
        } else {
            print("peripheral state: \(peripheral.state.rawValue)")
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        print("received read request")
        guard request.characteristic.uuid == portCharacteristicID else {
            peripheral.respond(to: request, withResult: .attributeNotFound)
            return
        }
        var uuid = profile.id.uuidString
        var correctUUID = uuid
        withUnsafePointer(to: &correctUUID) {
            let data = Data(bytes: $0, count: uuid.count)
            request.value = data
            peripheral.respond(to: request, withResult: .success)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        print("updated value")
        if let error = error { print(error); return }
        guard characteristic.uuid == portCharacteristicID,
              let data = characteristic.value else {
            print("id inválido")
            return
        }
        let uuid = data.withUnsafeBytes { $0.load(as: String.self) }
        self.foundUsers.append(uuid)
        guard let onFriendFound = onFriendFound else { return }
        onFriendFound(uuid)
    }

}
