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
    /// Random tie-breaker deciding who acts as central vs peripheral. Re-rolled on every `startBLE` so a
    /// repeated attempt against the same crowd doesn't deadlock on the same role decision twice.
    var advertisingKey: Int = Int.random(in: 1...100_000_000)
    
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
    private var pendingProfileData: Data = Data()
    private var sentByteCount: Int = 0

    /// The profile of the current user that will be transmitted to peers.
    let profile: User
    private var didSendProfile = false

    /// True once we have committed to a pairing attempt with a discovered peer, so further `didDiscover`
    /// callbacks in the same cycle are ignored instead of racing a second role decision.
    private var isPairing = false
    /// True once a complete friend profile has been received; suppresses any further pairing retries.
    private var didReceiveFriend = false
    /// True once the exchange-complete teardown has been scheduled; keeps `finishExchangeIfComplete`
    /// idempotent (it can be reached from both the send-finished and receive-finished paths).
    private var didFinishExchange = false
    /// Number of times the central has retried reading the PSM characteristic after a transient
    /// failure (peer hadn't finished publishing its L2CAP channel yet).
    private var psmReadRetries = 0
    private static let maxPSMReadRetries = 5

    /// Single-byte acknowledgement sent right after a peer's full profile is received. Lets each side
    /// confirm the other got its data before tearing down, so no one closes the channel mid-transfer
    /// (the cause of one-sided "achou / não achou" matches).
    private static let ackByte: UInt8 = 0x06
    /// True once the peer's ACK arrived, i.e. the peer confirmed it received OUR full profile.
    private var didReceiveAck = false
    /// Restarts discovery if a pairing attempt stalls — peer busy with someone else, failed connection,
    /// or a link that drops before the profile finishes arriving.
    private var pairingTimeoutTimer: Timer?
    /// How long to wait for a committed pairing attempt to deliver a profile before abandoning it.
    private static let pairingTimeoutSeconds: TimeInterval = 8
    /// Ignore peers weaker than this RSSI so that in a crowd we pair with the closest person, not a
    /// distant one whose handshake is more likely to be slow or to collide with other pairings.
    private static let minimumRSSI: Int = -75

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
        pendingProfileData = Data()
        sentByteCount = 0
        isPairing = false
        didReceiveFriend = false
        didReceiveAck = false
        didFinishExchange = false
        psmReadRetries = 0
        advertisingKey = Int.random(in: 1...100_000_000)
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
        self.peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }

    /// Stops all ongoing BLE scanning and advertising activities.
    func stopBLE() {
        print("stop ble")
        pairingTimeoutTimer?.invalidate()
        pairingTimeoutTimer = nil
        isPairing = false
        centralManager?.stopScan()
        if let peripheral = connectedPeripheral {
            peripheral.delegate = nil
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        centralManager?.delegate = nil
        peripheralManager?.stopAdvertising()
        peripheralManager?.delegate = nil
        closeStreams()
        connectedPeripheral = nil
        psm = nil
    }

    /// Closes and unschedules the L2CAP streams and drops the channel reference. Detaches the stream
    /// delegate first so a close we initiated doesn't bounce back as an `.endEncountered` event.
    private func closeStreams() {
        inputStream?.delegate = nil
        outputStream?.delegate = nil
        inputStream?.close()
        outputStream?.close()
        inputStream?.remove(from: .main, forMode: .default)
        outputStream?.remove(from: .main, forMode: .default)
        inputStream = nil
        outputStream = nil
        channelL2CAP = nil
    }

    // MARK: - Pairing recovery

    /// Starts a one-shot timer that abandons the current pairing attempt and re-scans if no profile
    /// arrives within `pairingTimeoutSeconds`.
    private func startPairingTimeout() {
        pairingTimeoutTimer?.invalidate()
        pairingTimeoutTimer = Timer.scheduledTimer(withTimeInterval: BLEManager.pairingTimeoutSeconds, repeats: false) { [weak self] _ in
            guard let self, !self.didReceiveFriend else { return }
            self.restartDiscovery(reason: "pairing timeout")
        }
    }

    /// Tears down the stalled attempt and starts a fresh scan/advertise cycle, unless a friend was
    /// already received (in which case the disconnect is just the expected end of a finished exchange).
    private func restartDiscovery(reason: String) {
        guard !didReceiveFriend else { return }
        print("reiniciando descoberta: \(reason)")
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.didReceiveFriend else { return }
            self.startBLE()
        }
    }

    /// Closes the channel and goes silent once the exchange is confirmed in both directions.
    ///
    /// Reaching here means we have the peer's profile (`didReceiveFriend`) and the peer ACKed ours
    /// (`didReceiveAck`) — so both sides already have each other's data and matched simultaneously.
    /// Our own ACK was sent before the peer's ACK could arrive, so the channel is safe to close now
    /// with nothing left in flight. `didReceiveFriend` stays true so the disconnect callbacks don't
    /// restart discovery.
    private func finishExchangeIfComplete() {
        guard didReceiveFriend, didReceiveAck, !didFinishExchange else { return }
        didFinishExchange = true
        print("troca completa, fechando channel")
        pairingTimeoutTimer?.invalidate()
        pairingTimeoutTimer = nil
        centralManager?.stopScan()
        peripheralManager?.stopAdvertising()
        closeStreams()
        if let peripheral = connectedPeripheral {
            peripheral.delegate = nil
            centralManager?.cancelPeripheralConnection(peripheral)
            connectedPeripheral = nil
        }
    }

    /// Reacts to a stream that closed or errored. If the exchange already finished this is the
    /// expected end of a completed handshake and is ignored; otherwise the link dropped mid-pairing
    /// (peer busy with someone else, etc.) so we re-scan for a fresh peer.
    private func handleStreamFailure(reason: String) {
        if didReceiveFriend { return }
        closeStreams()
        restartDiscovery(reason: reason)
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
        // Only commit to one peer per cycle; ignore the stream of repeat discoveries and anything
        // arriving after we've already paired.
        guard !isPairing, !didReceiveFriend else { return }
        guard let keyString = advertisementData[CBAdvertisementDataLocalNameKey] as? String,
              let peripheralKey = Int(keyString) else { return }

        // In a crowd, pair with the closest person. 127 is CoreBluetooth's "unknown RSSI" sentinel.
        let signal = rssi.intValue
        guard signal != 127, signal >= BLEManager.minimumRSSI else {
            print("ignorando peer distante (rssi \(signal))")
            return
        }

        isPairing = true
        startPairingTimeout()

        // Tie-breaker to decide which device acts as the central and which acts as the peripheral
        if peripheralKey > advertisingKey {
            print("virou peripheral")
            // L2CAP channel was already published at startup, so the PSM is ready before the central
            // reads it. Just stop scanning and keep advertising; wait for the central to open.
            centralManager.stopScan()
        } else {
            print("virou central")
            centralManager.stopScan()
            self.connectedPeripheral = peripheral
            centralManager.connect(connectedPeripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("falha ao conectar: \(error?.localizedDescription ?? "nil")")
        restartDiscovery(reason: "didFailToConnect")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("peripheral desconectou: \(error?.localizedDescription ?? "limpo")")
        restartDiscovery(reason: "didDisconnectPeripheral")
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("central connected")
        peripheral.delegate = self
        peripheral.discoverServices([serviceID])
    }

    /// Implemented only to silence CoreBluetooth's "delegate does not implement
    /// -[peripheral:didModifyServices:]" warning. Our service set is static, so nothing to do.
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        print("peripheral modificou serviços: \(invalidatedServices.count)")
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
            // Publish the L2CAP channel up-front so the PSM is ready before any central reads the
            // characteristic. Publishing it lazily in didDiscover raced the read and returned
            // CBATTError Code=10 (attributeNotFound) when the read won.
            peripheral.publishL2CAPChannel(withEncryption: false)
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
        if let error = error {
            print(error)
            // Transient read failure: peer hadn't finished publishing its L2CAP channel (Code=10), or a
            // cache pointed at a characteristic the peer no longer serves (Code=6). Retry a
            // few times; if it keeps failing, re-roll immediately instead of burning the pairing timeout.
            guard characteristic.uuid == portCharacteristicID else { return }
            if psmReadRetries < BLEManager.maxPSMReadRetries {
                psmReadRetries += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    guard let self, !self.didReceiveFriend else { return }
                    self.connectedPeripheral?.readValue(for: characteristic)
                }
            } else {
                restartDiscovery(reason: "psm read failed")
            }
            return
        }
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
        // Committed to this peer — go silent so no one else in a crowd connects mid-exchange.
        centralManager?.stopScan()
        peripheralManager?.stopAdvertising()
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
        // Already paired with someone this cycle — reject extra channels so a second peer can't
        // overwrite the in-flight streams. Cleared by stopBLE/finishExchangeIfComplete.
        guard channelL2CAP == nil else { print("já tem channel ativo, ignorando"); return }
        print("opened L2CAP channel (central)")
        setupStreams(for: channel)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didOpen channel: CBL2CAPChannel?, error: (any Error)?) {
        if let error = error { print(error); return }
        guard let channel = channel else { print("channel is nil"); return }
        // Already paired with someone this cycle — reject extra channels so a second peer can't
        // overwrite the in-flight streams. Cleared by stopBLE/finishExchangeIfComplete.
        guard channelL2CAP == nil else { print("já tem channel ativo, ignorando"); return }
        print("opened L2CAP channel (peripheral)")
        setupStreams(for: channel)
    }

    /// Reads incoming bytes from the input stream and appends them to the data buffer.
    func receiveData() {
        print("trying to receive data")
        guard let inputStream else { return }
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

    /// Decodes the received stream: first the length-prefixed `User` profile frame, then a trailing
    /// single ACK byte confirming the peer received our profile.
    func decodeData() throws {
        if !didReceiveFriend {
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
            // Drop the consumed profile frame; keep any trailing bytes (the peer's ACK may already be here).
            dataStream.removeSubrange(0..<expectedLength + 4)
            print("data decoded: \(friend.name)")
            didReceiveFriend = true
            pairingTimeoutTimer?.invalidate()
            pairingTimeoutTimer = nil
            enqueueAck()   // tell the peer we received their full profile
            DispatchQueue.main.async { self.onFriendFound?(friend) }
        }
        // A trailing ACK byte means the peer confirmed receipt of OUR profile. Only then is it safe to
        // tear down — guarantees neither side closes the channel before both have the data.
        if didReceiveFriend, !didReceiveAck, dataStream.contains(BLEManager.ackByte) {
            dataStream = Data()
            didReceiveAck = true
            print("ack recebido")
            finishExchangeIfComplete()
        }
    }

    /// Appends the ACK byte to the outgoing queue and flushes it. If the profile is still streaming the
    /// ACK rides out right after it; if already sent, this resumes the write with just the ACK.
    private func enqueueAck() {
        pendingProfileData.append(BLEManager.ackByte)
        sendPendingProfileData()
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
                    sendPendingProfileData()
                }
            }
        case .errorOccurred:
            print("erro na stream: \(aStream.streamError?.localizedDescription ?? "nil")")
            handleStreamFailure(reason: "stream error")
        case .endEncountered:
            print("stream fechada")
            // Peer may have sent its full profile and then closed; drain whatever is still buffered
            // before deciding this was a failure, so a clean close right after the last write still
            // lets this side complete the match (avoids one-sided "achou / não achou").
            if aStream === inputStream { receiveData() }
            handleStreamFailure(reason: "stream closed")
        default:
            break
        }
    }

    /// Encodes the current user's profile and queues it for transmission to the connected peer.
    ///
    /// The payload is framed with a 4-byte big-endian length prefix and then streamed out by
    /// `sendPendingProfileData()`, which keeps writing the remainder on each `.hasSpaceAvailable` event until the
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

        pendingProfileData = payload
        sentByteCount = 0
        print("queued profile payload (\(payload.count) bytes)")
        sendPendingProfileData()
    }

    /// Writes as many pending bytes of `pendingProfileData` as the stream currently accepts, advancing
    /// `sentByteCount`. Re-invoked on every `.hasSpaceAvailable` event until the payload is fully sent.
    private func sendPendingProfileData() {
        guard let output = outputStream, sentByteCount < pendingProfileData.count else { return }

        while sentByteCount < pendingProfileData.count, output.hasSpaceAvailable {
            let remaining = pendingProfileData.count - sentByteCount
            let written = pendingProfileData.withUnsafeBytes { raw -> Int in
                guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return -1 }
                return output.write(base + sentByteCount, maxLength: remaining)
            }
            guard written > 0 else {
                print("erro ao enviar dados (\(written))")
                break
            }
            sentByteCount += written
        }

        if sentByteCount >= pendingProfileData.count {
            print("payload fully sent (\(pendingProfileData.count) bytes)")
        } else {
            print("payload partially sent (\(sentByteCount)/\(pendingProfileData.count) bytes), awaiting space")
        }
    }
}
