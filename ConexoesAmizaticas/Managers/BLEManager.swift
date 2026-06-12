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

    /// Profile picture sent over BLE. Tune these to trade quality against transfer size:
    /// the transfer is fast (tens of KB in well under a second), so a moderate bump barely affects
    /// the time to connect — discovery and the L2CAP handshake dominate that, not the bytes.
    private static let profileImageSide: CGFloat = 256        // px (square)
    private static let profileImageQuality: CGFloat = 0.7     // JPEG quality 0...1

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
    /// True once our profile has been added to the outgoing queue (so we queue it only once).
    private var didQueueProfile = false
    /// True once our ACK byte has been added to the outgoing queue.
    private var didQueueAck = false

    /// True once we've committed to a peer this cycle, so extra `didDiscover` callbacks are ignored.
    private var isPairing = false
    /// True once the peer's full profile arrived. Also stops any restart, since the exchange is done.
    private var didReceiveFriend = false
    /// True once the peer's ACK arrived — they confirmed they received OUR profile.
    private var didReceiveAck = false
    /// Guards `finishExchangeIfComplete` so the teardown runs only once.
    private var didFinishExchange = false
    /// Retry counter for reading the peer's PSM characteristic when it isn't ready yet.
    private var psmReadRetries = 0
    private static let maxPSMReadRetries = 5

    /// One-byte acknowledgement. After receiving a peer's full profile we send this so they know we
    /// got it; we close only after receiving theirs. Guarantees both sides have the data before close.
    private static let ackByte: UInt8 = 0x06
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

    /// Starts (or restarts) scanning and advertising. The managers are created once and reused — we
    /// never recreate them per attempt, which used to churn the bluetoothd XPC connection and crash.
    func startBLE() {
        print("start ble")
        resetSession()
        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: nil)
        }
        if peripheralManager == nil {
            peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        }
        // On the first run the managers aren't powered on yet, so the state callbacks start the work.
        // On a restart they're already on, so kick off here.
        beginScanning()
        beginAdvertising()
    }

    /// Fully stops BLE and releases the managers. Used when leaving the screen.
    func stopBLE() {
        print("stop ble")
        resetSession()
        centralManager?.stopScan()
        centralManager?.delegate = nil
        centralManager = nil
        peripheralManager?.stopAdvertising()
        peripheralManager?.delegate = nil
        peripheralManager = nil
        psm = nil
    }

    /// Clears all per-attempt state and tears down the current link, without touching the managers.
    private func resetSession() {
        pairingTimeoutTimer?.invalidate()
        pairingTimeoutTimer = nil
        closeStreams()
        if let peripheral = connectedPeripheral {
            peripheral.delegate = nil
            centralManager?.cancelPeripheralConnection(peripheral)
            connectedPeripheral = nil
        }
        dataStream = Data()
        pendingProfileData = Data()
        sentByteCount = 0
        didQueueProfile = false
        didQueueAck = false
        isPairing = false
        didReceiveFriend = false
        didReceiveAck = false
        didFinishExchange = false
        psmReadRetries = 0
        advertisingKey = Int.random(in: 1...100_000_000)
    }

    /// Starts scanning for peers, if the central is ready.
    private func beginScanning() {
        guard centralManager?.state == .poweredOn else { return }
        centralManager.scanForPeripherals(withServices: [serviceID], options: nil)
    }

    /// (Re)starts advertising with the current key, if the peripheral is ready.
    private func beginAdvertising() {
        guard peripheralManager?.state == .poweredOn else { return }
        peripheralManager.stopAdvertising()
        peripheralManager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [serviceID],
            CBAdvertisementDataLocalNameKey: "\(advertisingKey)"
        ])
    }

    /// Closes and unschedules the L2CAP streams. Detaches the delegate first so our own close doesn't
    /// come back as an `.endEncountered` event.
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

    /// Drops the stalled attempt and scans again, reusing the existing managers. Skipped if a friend
    /// was already received (then the disconnect is just the normal end of a finished exchange).
    private func restartDiscovery(reason: String) {
        guard !didReceiveFriend else { return }
        print("reiniciando descoberta: \(reason)")
        resetSession()
        beginScanning()
        beginAdvertising()
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
            beginScanning()
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
            // Publish the L2CAP channel up-front so the PSM is ready before any central reads it.
            // Doing it lazily raced the read and returned CBATTError Code=10 (attributeNotFound).
            peripheral.publishL2CAPChannel(withEncryption: false)
            beginAdvertising()
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
        // Open the peer's channel with their PSM. Keep `self.psm` (our own published PSM) untouched so
        // a future read of our characteristic still serves the right value.
        let peerPSM = data.withUnsafeBytes { $0.load(as: CBL2CAPPSM.self) }
        peripheral.openL2CAPChannel(peerPSM)
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
        onConnectionOpened?()
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
            queueAck()   // tell the peer we received their full profile
            onFriendFound?(friend)
        }
        // A trailing ACK byte means the peer received OUR profile. Now both sides have the data, so
        // it's safe to close.
        if didReceiveFriend, !didReceiveAck, dataStream.contains(BLEManager.ackByte) {
            dataStream = Data()
            didReceiveAck = true
            print("ack recebido")
            finishExchangeIfComplete()
        }
    }

    /// Queues our ACK byte. Always queues our profile first, so on the wire the peer reads
    /// [profile][ack] in order and never mistakes the ACK byte for the profile's length prefix.
    private func queueAck() {
        queueProfile()
        guard !didQueueAck else { return }
        didQueueAck = true
        pendingProfileData.append(BLEManager.ackByte)
        flushOutgoing()
    }

    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case .hasBytesAvailable:
            receiveData()
        case .openCompleted:
            if aStream === outputStream { queueProfile() }
        case .hasSpaceAvailable:
            if aStream === outputStream {
                queueProfile()
                flushOutgoing()
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

    /// Adds our profile to the outgoing queue exactly once, framed with a 4-byte big-endian length
    /// prefix. The bytes are streamed out by `flushOutgoing()` across multiple `.hasSpaceAvailable`
    /// events, so a full-size picture can be sent safely. Encoding failure is ignored (profile stays unsent).
    private func queueProfile() {
        guard !didQueueProfile else { return }
        let pictureToSend: Data
        if let image = UIImage(data: profile.profilePicture),
           let compressed = image
               .squareThumbnail(side: BLEManager.profileImageSide)
               .jpegData(compressionQuality: BLEManager.profileImageQuality) {
            pictureToSend = compressed
        } else {
            pictureToSend = profile.profilePicture
        }
        let profileDTO = UserDTO(name: profile.name, profilePicture: pictureToSend, id: profile.id)
        guard let jsonData = try? JSONEncoder().encode(profileDTO) else { return }

        didQueueProfile = true
        var length = UInt32(jsonData.count).bigEndian
        pendingProfileData.append(Data(bytes: &length, count: 4))
        pendingProfileData.append(jsonData)
        print("queued profile payload (\(pendingProfileData.count) bytes)")
        flushOutgoing()
    }

    /// Writes as many queued bytes as the stream currently accepts, advancing `sentByteCount`.
    /// Re-invoked on every `.hasSpaceAvailable` event until the queue is fully drained.
    private func flushOutgoing() {
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
