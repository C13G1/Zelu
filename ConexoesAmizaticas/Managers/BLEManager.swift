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

/// A lightweight Data Transfer Object used exclusively for serializing `User` payloads over the BLE
/// L2CAP stream before they are reconstructed as full SwiftData models on the receiver side.
struct UserDTO: Codable {
    var name: String
    var profilePicture: Data
    var id: UUID
}

/// A manager responsible for discovering and establishing Bluetooth Low Energy (BLE) connections with nearby peers.
///
/// `BLEManager` acts as both a Central and a Peripheral. It broadcasts the user's profile and scans for other users
/// broadcasting the specific app service. Once connected, it uses an L2CAP channel to stream profile data.
class BLEManager: NSObject, CBCentralManagerDelegate, CBPeripheralManagerDelegate, CBPeripheralDelegate, StreamDelegate {

    /// Maximum bytes read from the L2CAP input stream in a single pass.
    private static let bufferSize: Int = 1024

    /// A closure triggered when a complete user profile is successfully received over the BLE stream.
    var onFriendFound: ((User) -> Void)?
    
    /// A closure triggered when the L2CAP data stream is successfully opened and ready for data transfer.
    var onConnectionOpened: (() -> Void)?

    var centralManager: CBCentralManager!
    var peripheralManager: CBPeripheralManager!
    var connectedPeripheral: CBPeripheral!
    
    let serviceID: CBUUID = CBUUID(string: "451A3F17-0062-41E1-82CC-98496CDA05FB")
    let portCharacteristicID: CBUUID = CBUUID(string: "B2C20EFB-B20F-4F0D-B708-4EA408F2C500")
    let advertisingKey: Int = Int.random(in: 1...100_000_000)
    
    var psm: CBL2CAPPSM!
    var channelL2CAP: CBL2CAPChannel!
    var inputStream: InputStream!
    var outputStream: OutputStream!
    var dataStream: Data = Data()

    /// Outgoing profile payload and the number of bytes already written to the stream.
    ///
    /// L2CAP `OutputStream.write` is not guaranteed to accept the whole payload in one call — it writes
    /// as much as the kernel buffer currently holds and returns that count. The remaining bytes must be
    /// flushed on subsequent `.hasSpaceAvailable` events; without this the tail of a larger image was
    /// silently dropped, which is why the picture had to be shrunk to a tiny thumbnail to fit one write.
    private var outgoingData: Data = Data()
    private var outgoingOffset: Int = 0

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
        dataStream = Data()
        outgoingData = Data()
        outgoingOffset = 0
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
        self.peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }

    /// Stops all ongoing BLE scanning and advertising activities.
    func stopBLE() {
        print("stop ble")
        centralManager?.stopScan()
        if let peripheral = connectedPeripheral {
            peripheral.delegate = nil
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        centralManager?.delegate = nil
        peripheralManager?.stopAdvertising()
        peripheralManager?.delegate = nil
        inputStream?.close()
        outputStream?.close()
        inputStream?.remove(from: .main, forMode: .default)
        outputStream?.remove(from: .main, forMode: .default)
        inputStream = nil
        outputStream = nil
        channelL2CAP = nil
        connectedPeripheral = nil
        psm = nil
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
            self.connectedPeripheral = peripheral
            centralManager.connect(connectedPeripheral)
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
        guard request.characteristic.uuid == portCharacteristicID, self.psm != nil else {
            peripheral.respond(to: request, withResult: .attributeNotFound)
            return
        }
        
        var psmValue = self.psm!
        let data = Data(bytes: &psmValue, count: MemoryLayout<CBL2CAPPSM>.size)
        request.value = data
        peripheral.respond(to: request, withResult: .success)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        print("updated value")
        if let error = error { print(error); return }
        guard characteristic.uuid == portCharacteristicID,
              let data = characteristic.value,
              data.count >= MemoryLayout<CBL2CAPPSM>.size else {
            print("psm data inválido")
            return
        }
        self.psm = data.withUnsafeBytes { $0.load(as: CBL2CAPPSM.self) }
        peripheral.openL2CAPChannel(self.psm)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didPublishL2CAPChannel PSM: CBL2CAPPSM, error: (any Error)?) {
        if let error = error { print(error); return }
        print("published L2CAP channel")
        self.psm = PSM
    }

    // MARK: - Stream Handling

    private func setupStreams(for channel: CBL2CAPChannel) {
        guard let output = channel.outputStream,
              let input = channel.inputStream else {
            print("couldnt create streams")
            return
        }
        self.channelL2CAP = channel
        self.outputStream = output
        self.inputStream = input
        self.outputStream.delegate = self
        self.inputStream.delegate = self
        self.inputStream.schedule(in: .main, forMode: .default)
        self.outputStream.schedule(in: .main, forMode: .default)
        self.outputStream.open()
        self.inputStream.open()
        DispatchQueue.main.async { self.onConnectionOpened?() }
    }

    func peripheral(_ peripheral: CBPeripheral, didOpen channel: CBL2CAPChannel?, error: (any Error)?) {
        if let error = error { print(error); return }
        guard let channel = channel else { print("channel is nil"); return }
        guard channelL2CAP == nil else { print("channel already open, ignoring"); return }
        print("opened L2CAP channel (central)")
        setupStreams(for: channel)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didOpen channel: CBL2CAPChannel?, error: (any Error)?) {
        if let error = error { print(error); return }
        guard let channel = channel else { print("channel is nil"); return }
        guard channelL2CAP == nil else { print("channel already open, ignoring"); return }
        print("opened L2CAP channel (peripheral)")
        setupStreams(for: channel)
    }

    /// Reads incoming bytes from the input stream and appends them to the data buffer.
    func receiveData() {
        print("trying to receive data")
        var buffer = [UInt8](repeating: 0, count: BLEManager.bufferSize)
        while inputStream.hasBytesAvailable {
            let bytesReceived = inputStream.read(&buffer, maxLength: BLEManager.bufferSize)
            if bytesReceived > 0 {
                self.dataStream.append(contentsOf: buffer.prefix(bytesReceived))
            }
        }
        do {
            try decodeData()
        } catch {
            print("erro decodificando data: \(error)")
        }
    }

    /// Decodes the received JSON data stream into a `User` profile.
    func decodeData() throws {
        guard dataStream.count >= 4 else { return }
        let expectedLength = dataStream.withUnsafeBytes {
            Int(UInt32(bigEndian: $0.load(as: UInt32.self)))
        }
        guard dataStream.count >= expectedLength + 4 else {
            print("aguardando dados: \(dataStream.count)/\(expectedLength + 4) bytes")
            return
        }
        let jsonData = dataStream.subdata(in: 4..<expectedLength + 4)
        let friendDTO = try JSONDecoder().decode(UserDTO.self, from: jsonData)
        let friend = User(name: friendDTO.name, profilePicture: friendDTO.profilePicture, id: friendDTO.id)
        print("data decoded: \(friend.name)")
        dataStream = Data()
        DispatchQueue.main.async { self.onFriendFound?(friend) }
    }

    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case .hasBytesAvailable:
            receiveData()
        case .openCompleted:
            if aStream === outputStream && !didSendProfile && outputStream.hasSpaceAvailable {
                didSendProfile = true
                try? sendProfile()
            }
        case .hasSpaceAvailable:
            if aStream === outputStream {
                if !didSendProfile {
                    didSendProfile = true
                    try? sendProfile()
                } else {
                    flushOutgoing()
                }
            }
        case .errorOccurred:
            print("erro na stream")
        case .endEncountered:
            print("stream fechada")
        default:
            break
        }
    }

    /// Encodes the current user's profile and queues it for transmission to the connected peer.
    ///
    /// The payload is framed with a 4-byte big-endian length prefix and then streamed out by
    /// `flushOutgoing()`, which keeps writing the remainder on each `.hasSpaceAvailable` event until the
    /// whole thing has been sent. This is what lets us transmit a higher-quality picture safely.
    ///
    /// - Throws: An error if JSON encoding fails.
    func sendProfile() throws {
        print("trying to send data")
        let pictureToSend: Data
        if let image = UIImage(data: profile.profilePicture),
           let thumb = image.preparingThumbnail(of: CGSize(width: 256, height: 256)),
           let compressed = thumb.jpegData(compressionQuality: 0.7) {
            pictureToSend = compressed
        } else {
            pictureToSend = profile.profilePicture
        }
        let profileDTO = UserDTO(name: profile.name, profilePicture: pictureToSend, id: profile.id)
        let jsonData = try JSONEncoder().encode(profileDTO)

        var length = UInt32(jsonData.count).bigEndian
        var payload = Data(bytes: &length, count: 4)
        payload.append(jsonData)

        outgoingData = payload
        outgoingOffset = 0
        print("queued profile payload (\(payload.count) bytes)")
        flushOutgoing()
    }

    /// Writes as many pending bytes of `outgoingData` as the stream currently accepts, advancing
    /// `outgoingOffset`. Re-invoked on every `.hasSpaceAvailable` event until the payload is fully sent.
    private func flushOutgoing() {
        guard let output = outputStream, outgoingOffset < outgoingData.count else { return }

        while outgoingOffset < outgoingData.count, output.hasSpaceAvailable {
            let remaining = outgoingData.count - outgoingOffset
            let written = outgoingData.withUnsafeBytes { raw -> Int in
                guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return -1 }
                return output.write(base + outgoingOffset, maxLength: remaining)
            }
            guard written > 0 else {
                print("erro ao enviar dados (\(written))")
                break
            }
            outgoingOffset += written
        }

        if outgoingOffset >= outgoingData.count {
            print("profile fully sent (\(outgoingData.count) bytes)")
        } else {
            print("profile partially sent (\(outgoingOffset)/\(outgoingData.count) bytes), awaiting space")
        }
    }
}
