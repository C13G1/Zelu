//
//  NearbyManager.swift
//  ConexoesAmizaticas
//
//  Created by Enzo Ferroni on 09/06/26.
//

import Foundation
import CoreBluetooth
import UIKit

/// A person discovered nearby, as shown in the "Pessoas por perto" grid.
///
/// Starts as a name-only placeholder (`hasPhoto == false`, default avatar) the instant the peer's
/// identity arrives, and is upgraded with the real photo a moment later. `sentInvite` / `receivedInvite`
/// drive the tap-to-meet state (ring colour and badge) in `NearbyPeopleView`.
struct NearbyPerson: Identifiable, Equatable {
    var user: User
    /// False while only the name has arrived; true once the photo has been received.
    var hasPhoto: Bool
    /// We tapped them and sent a meeting invite (waiting for them to tap back).
    var sentInvite: Bool = false
    /// They tapped us — "quer te encontrar".
    var receivedInvite: Bool = false

    var id: UUID { user.id }

    static func == (lhs: NearbyPerson, rhs: NearbyPerson) -> Bool {
        lhs.user.id == rhs.user.id && lhs.hasPhoto == rhs.hasPhoto
            && lhs.sentInvite == rhs.sentInvite && lhs.receivedInvite == rhs.receivedInvite
    }
}

/// Discovers every nearby app user over BLE and runs the AirDrop-style "Pessoas por perto" experience.
///
/// Where `BLEManager` auto-pairs with a single closest peer, `NearbyManager` shows *everyone* around and
/// lets the user choose. Each device is simultaneously a Central (it scans and connects) and a Peripheral
/// (it advertises and accepts connections), so every pair ends up with one shared L2CAP link.
///
/// How it works, end to end:
/// 1. **Discover** – everyone advertises a random key and scans. To avoid two links per pair, a tie-breaker
///    decides who connects: the device with the *lower* key dials, the other waits. One link per pair.
/// 2. **Exchange** – over that link each side sends a tiny `identity` message (name shows instantly) then
///    its `profile` (the photo, which loads a moment later). Messages are framed by `MessageFramer`.
/// 3. **Stay honest** – a heartbeat pings every few seconds; a peer that goes silent (left the screen,
///    crashed, walked away) drops off the grid. A clean exit removes them immediately.
/// 4. **Invite** – tapping a person sends an `invite`. When both sides have invited each other, that is a
///    mutual match: `onMutualMatch` fires, the pair leaves for the meeting screen and (via `pauseForMeeting`)
///    vanishes from everyone else's grid until they come back.
@Observable
final class NearbyManager: NSObject {

    /// The people currently nearby. Driven by Bluetooth; bound directly to the grid.
    private(set) var people: [NearbyPerson] = []

    /// Fired once when this device and a peer have invited each other. The view routes to the meeting flow.
    var onMutualMatch: ((User) -> Void)?

    /// This device's profile, sent to every peer we link with.
    let profile: User

    // MARK: - Wire protocol

    /// The kinds of message exchanged over a link. Each is framed as `[length][type][body]`.
    private enum MessageType: UInt8 {
        case identity = 0x01   // body: IdentityDTO JSON (id + name) — tiny, shows the name instantly
        case profile  = 0x02   // body: UserDTO JSON (id + name + photo)
        case invite   = 0x03   // body: empty — "I want to meet you"
        case cancel   = 0x04   // body: empty — invite withdrawn
        case ping     = 0x05   // body: empty — liveness heartbeat
    }

    /// The lightweight first message: just enough to show a name before the photo arrives.
    private struct IdentityDTO: Codable { let id: UUID; let name: String }

    // MARK: - Bluetooth

    /// Service + characteristic UUIDs. Must match the peer app exactly (shared with `BLEManager`).
    private let serviceID = CBUUID(string: "451A3F17-0062-41E1-82CC-98496CDA05FB")
    private let portCharacteristicID = CBUUID(string: "B2C20EFB-B20F-4F0D-B708-4EA408F2C500")

    private var centralManager: CBCentralManager?
    private var peripheralManager: CBPeripheralManager?
    /// Our published L2CAP PSM (peripheral side), served from the read characteristic.
    private var psm: CBL2CAPPSM?
    /// The GATT service is added once; this guards against re-adding it on later power-on callbacks.
    private var didAddService = false
    /// A random number advertised so both sides of a pair can run the same connect tie-breaker. Stable
    /// for the whole session so the decision never flips mid-discovery.
    private let advertisingKey = Int.random(in: 1...100_000_000)

    // MARK: - Links

    /// Every active peer link, looked up by the identity of either of its streams (for fast demux).
    private var links: [ObjectIdentifier: Link] = [:]
    /// The same links as a list, for iteration.
    private var allLinks: [Link] = []
    /// Peripherals we're mid-connection with, with the time we started — used to time out stalls.
    private var connecting: [UUID: Date] = [:]

    // MARK: - Tunables

    /// Bytes read from a stream per pass.
    private static let bufferSize = 1024
    /// A peer silent for this long (no message, not even a heartbeat) is dropped.
    private static let silenceTimeout: TimeInterval = 8
    /// A connection attempt that hasn't produced a link within this long is abandoned.
    private static let connectTimeout: TimeInterval = 6
    /// How often we ping peers and sweep stale state.
    private static let heartbeatInterval: TimeInterval = 3

    private var heartbeatTimer: Timer?
    /// True between `pauseForMeeting()` and `resume()`: we go invisible and stop forming links.
    private var paused = false

    init(profile: User) {
        self.profile = profile
        super.init()
    }

    // MARK: - Lifecycle

    /// Creates the Bluetooth managers (once) and begins scanning + advertising. Safe to call repeatedly.
    func start() {
        print("nearby start")
        paused = false
        if centralManager == nil { centralManager = CBCentralManager(delegate: self, queue: nil) }
        if peripheralManager == nil { peripheralManager = CBPeripheralManager(delegate: self, queue: nil) }
        beginScanning()
        beginAdvertising()
        startHeartbeat()
    }

    /// Full teardown — call when the grid screen is left for good. Releases the managers and clears state.
    func stop() {
        print("nearby stop")
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        teardownAllLinks()
        centralManager?.stopScan()
        centralManager?.delegate = nil
        centralManager = nil
        peripheralManager?.stopAdvertising()
        peripheralManager?.delegate = nil
        peripheralManager = nil
        psm = nil
        didAddService = false
        paused = false
        people.removeAll()
    }

    /// Called on a mutual match: stop being discoverable and close every link so the pair disappears from
    /// other people's grids while they confirm the meeting. The link teardown is delayed a beat so the
    /// final invite message flushes to the peer before the channel closes.
    func pauseForMeeting() {
        print("nearby pause (meeting)")
        paused = true
        centralManager?.stopScan()
        peripheralManager?.stopAdvertising()
        people.removeAll()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self, self.paused else { return }
            self.teardownAllLinks()
        }
    }

    /// Called when returning from the meeting: become discoverable again and rebuild the grid from scratch.
    func resume() {
        guard centralManager != nil else { start(); return }
        print("nearby resume")
        paused = false
        beginScanning()
        beginAdvertising()
    }

    /// Starts scanning for peers, once the Central is powered on.
    private func beginScanning() {
        guard !paused, centralManager?.state == .poweredOn else { return }
        centralManager?.scanForPeripherals(withServices: [serviceID],
                                           options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }

    /// (Re)starts advertising our key, once the Peripheral is powered on.
    private func beginAdvertising() {
        guard !paused, let peripheralManager, peripheralManager.state == .poweredOn else { return }
        peripheralManager.stopAdvertising()
        peripheralManager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [serviceID],
            CBAdvertisementDataLocalNameKey: "\(advertisingKey)"
        ])
    }

    // MARK: - Heartbeat & liveness

    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: NearbyManager.heartbeatInterval,
                                              repeats: true) { [weak self] _ in self?.tick() }
    }

    /// Runs every `heartbeatInterval`: ping all peers, drop the silent ones, and clear stalled connects.
    private func tick() {
        let now = Date.now
        for link in allLinks { send(.ping, on: link) }
        for link in allLinks where now.timeIntervalSince(link.lastHeard) > NearbyManager.silenceTimeout {
            print("nearby drop (silent): \(link.user?.name ?? "?")")
            tearDownLink(link)
        }
        let stalled = connecting.filter { now.timeIntervalSince($0.value) > NearbyManager.connectTimeout }
        for identifier in stalled.keys {
            print("nearby connect timeout")
            connecting[identifier] = nil
        }
    }

    // MARK: - Grid mutations
    //
    // `people` is the single source of truth for the UI. These helpers are the only writers, so the
    // grid stays consistent and every change re-renders the view.

    /// Inserts the person, or refreshes their name/photo if already on the grid. A nil `photo` means
    /// "name only" — any photo that already arrived is kept.
    private func upsert(id: UUID, name: String, photo: Data?) {
        if let index = people.firstIndex(where: { $0.user.id == id }) {
            let keptPhoto = photo ?? (people[index].hasPhoto ? people[index].user.profilePicture : Data())
            people[index].user = User(name: name, profilePicture: keptPhoto, id: id)
            if photo != nil { people[index].hasPhoto = true }
        } else {
            people.append(NearbyPerson(user: User(name: name, profilePicture: photo ?? Data(), id: id),
                                       hasPhoto: photo != nil))
        }
    }

    /// Mutates the grid entry for `id` in place. No-op if the person already left.
    private func updatePerson(_ id: UUID, _ change: (inout NearbyPerson) -> Void) {
        guard let index = people.firstIndex(where: { $0.user.id == id }) else { return }
        change(&people[index])
    }

    private func remove(id: UUID?) {
        guard let id else { return }
        people.removeAll { $0.user.id == id }
    }

    // MARK: - Invites

    /// Toggles a meeting invite to the tapped person: sends one if none is pending, withdraws it
    /// otherwise. If they had already invited us, this completes a mutual match.
    func toggleInvite(_ userID: UUID) {
        guard let link = link(for: userID) else {
            #if DEBUG
            // Mock people have no real link — jump straight to the match so the flow can be tested solo.
            if let person = people.first(where: { $0.user.id == userID }) { onMutualMatch?(person.user) }
            #endif
            return
        }
        link.iInvited.toggle()
        send(link.iInvited ? .invite : .cancel, on: link)
        updatePerson(userID) { $0.sentInvite = link.iInvited }
        checkMutual(link)
    }

    /// Fires `onMutualMatch` exactly once, when both sides of a link have invited each other.
    private func checkMutual(_ link: Link) {
        guard link.iInvited, link.theyInvited, !link.didMatch, let user = link.user else { return }
        link.didMatch = true
        print("nearby mutual match: \(user.name)")
        onMutualMatch?(user)
    }

    // MARK: - Per-peer link

    /// Everything tied to one peer connection: its streams, send buffer, message framer, and the state
    /// (profile, invites) used to decide a mutual match.
    private final class Link {
        var channel: CBL2CAPChannel?
        var input: InputStream?
        var output: OutputStream?
        /// Splits the incoming byte stream back into whole messages.
        var framer = MessageFramer()
        /// Outgoing bytes waiting for stream space, and how many have already been written.
        var tx = Data()
        var sent = 0
        /// Our profile is queued onto the stream only once.
        var queuedOutgoing = false
        var userID: UUID?
        /// The decoded peer profile, handed to the UI on a mutual match.
        var user: User?
        var iInvited = false
        var theyInvited = false
        /// Guards the mutual-match callback so it fires once.
        var didMatch = false
        /// Last time we heard anything from this peer; drives the silence timeout.
        var lastHeard = Date.now
        /// The peer object, on links where we are the Central. Nil when we are the Peripheral.
        weak var peripheral: CBPeripheral?
    }

    private func link(for userID: UUID) -> Link? {
        allLinks.first { $0.userID == userID }
    }

    /// Wires up the streams of a freshly opened channel and registers the link.
    private func setupLink(for channel: CBL2CAPChannel, peripheral: CBPeripheral?) {
        guard let input = channel.inputStream, let output = channel.outputStream else { return }
        if let peripheral { connecting[peripheral.identifier] = nil }
        let link = Link()
        link.channel = channel
        link.input = input
        link.output = output
        link.peripheral = peripheral
        link.lastHeard = .now
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

    /// Closes a link's streams and drops the peer connection, without touching the grid.
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
            connecting[peripheral.identifier] = nil
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        allLinks.removeAll { $0 === link }
    }

    /// Removes the peer from the grid and closes their link.
    private func tearDownLink(_ link: Link) {
        remove(id: link.userID)
        closeLink(link)
    }

    private func teardownAllLinks() {
        for link in allLinks { closeLink(link) }
        allLinks.removeAll()
        links.removeAll()
        connecting.removeAll()
    }

    // MARK: - Sending

    /// Frames a message and queues it for the peer. `MessageFramer` handles the byte layout.
    private func send(_ type: MessageType, body: Data = Data(), on link: Link) {
        guard link.output != nil else { return }
        link.tx.append(MessageFramer.frame(type.rawValue, body: body))
        flush(link)
    }

    /// Queues our identity (name, instant) then our profile (photo, loads after) — once per link.
    private func queueOutgoing(on link: Link) {
        guard !link.queuedOutgoing else { flush(link); return }
        link.queuedOutgoing = true
        if let json = try? JSONEncoder().encode(IdentityDTO(id: profile.id, name: profile.name)) {
            send(.identity, body: json, on: link)
        }
        let dto = UserDTO(name: profile.name, profilePicture: compressedPhoto(), id: profile.id)
        if let json = try? JSONEncoder().encode(dto) {
            send(.profile, body: json, on: link)
        }
    }

    /// Our profile photo, squared down to a small JPEG so it transfers quickly.
    private func compressedPhoto() -> Data {
        if let image = UIImage(data: profile.profilePicture),
           let thumb = image.preparingThumbnail(of: CGSize(width: 256, height: 256))?
               .jpegData(compressionQuality: 0.7) {
            return thumb
        }
        return profile.profilePicture
    }

    /// Writes as many queued bytes as the stream currently accepts; re-invoked on each `.hasSpaceAvailable`.
    /// A large photo won't fit in one write, so this drains the buffer across several events.
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
        if link.sent == link.tx.count, link.sent > 0 {   // buffer drained — reclaim it
            link.tx.removeAll(keepingCapacity: false)
            link.sent = 0
        }
    }

    // MARK: - Receiving

    /// Reads available bytes into the link's framer, then processes every whole message that arrived.
    private func receive(on link: Link) {
        guard let input = link.input else { return }
        link.lastHeard = .now
        var buffer = [UInt8](repeating: 0, count: NearbyManager.bufferSize)
        while input.hasBytesAvailable {
            let read = input.read(&buffer, maxLength: NearbyManager.bufferSize)
            if read > 0 { link.framer.append(Data(buffer.prefix(read))) }
        }
        drainMessages(on: link)
    }

    /// Hands each complete message to `handle`. Drops the link if the framing is corrupt.
    private func drainMessages(on link: Link) {
        while true {
            let message: (type: UInt8, body: Data)?
            do {
                message = try link.framer.next()
            } catch {
                print("nearby corrupt stream, dropping link")
                tearDownLink(link)
                return
            }
            guard let message else { return }
            if let type = MessageType(rawValue: message.type) {
                handle(type, body: message.body, on: link)
            }
        }
    }

    /// Applies one received message to the link and the grid.
    private func handle(_ type: MessageType, body: Data, on link: Link) {
        switch type {
        case .identity:
            guard let dto = try? JSONDecoder().decode(IdentityDTO.self, from: body) else { return }
            ingest(id: dto.id, name: dto.name, photo: nil, on: link)
        case .profile:
            guard let dto = try? JSONDecoder().decode(UserDTO.self, from: body) else { return }
            ingest(id: dto.id, name: dto.name, photo: dto.profilePicture, on: link)
        case .invite:
            link.theyInvited = true
            if let id = link.userID { updatePerson(id) { $0.receivedInvite = true } }
            checkMutual(link)
        case .cancel:
            link.theyInvited = false
            if let id = link.userID { updatePerson(id) { $0.receivedInvite = false } }
        case .ping:
            break   // lastHeard already refreshed in receive(on:)
        }
    }

    /// Records a peer's profile — from the lightweight identity or the full photo message — onto the link
    /// and the grid, then reflects any pending invite and checks for a mutual match.
    private func ingest(id: UUID, name: String, photo: Data?, on link: Link) {
        link.userID = id
        if let photo {
            link.user = User(name: name, profilePicture: photo, id: id)
        } else if link.user == nil {
            link.user = User(name: name, profilePicture: Data(), id: id)
        }
        upsert(id: id, name: name, photo: photo)
        if link.theyInvited { updatePerson(id) { $0.receivedInvite = true } }
        checkMutual(link)
    }

    #if DEBUG
    /// Seeds the grid with fake people (no real links) so the UI can be exercised on a single device.
    func injectMockPeople() {
        let picture = UIImage(named: "defaultPicture")?.jpegData(compressionQuality: 0.8) ?? Data()
        for name in ["Osmar", "Ed Sheeran", "Laura", "Juliana", "Thais"] {
            guard !people.contains(where: { $0.user.name == name }) else { continue }
            people.append(NearbyPerson(user: User(name: name, profilePicture: picture), hasPhoto: true))
        }
    }
    #endif
}

// MARK: - CBCentralManagerDelegate (scan & connect)

extension NearbyManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else {
            print("nearby central state \(central.state.rawValue)")
            return
        }
        beginScanning()
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi: NSNumber) {
        guard !paused,
              let keyString = advertisementData[CBAdvertisementDataLocalNameKey] as? String,
              let peerKey = Int(keyString) else { return }
        // Tie-breaker: the lower key dials, the higher key waits — so each pair forms exactly one link.
        guard peerKey < advertisingKey else { return }
        // Don't dial someone we're already connecting to or linked with.
        guard connecting[peripheral.identifier] == nil,
              !allLinks.contains(where: { $0.peripheral?.identifier == peripheral.identifier }) else { return }
        connecting[peripheral.identifier] = .now
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("nearby didFailToConnect: \(error?.localizedDescription ?? "nil")")
        connecting[peripheral.identifier] = nil
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connecting[peripheral.identifier] = nil
        if let link = allLinks.first(where: { $0.peripheral?.identifier == peripheral.identifier }) {
            tearDownLink(link)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([serviceID])
    }
}

// MARK: - CBPeripheralDelegate (central side: read the peer's PSM, open the channel)

extension NearbyManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {}

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics([portCharacteristicID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil, let characteristics = service.characteristics else { return }
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
        guard error == nil, let channel else {
            connecting[peripheral.identifier] = nil
            return
        }
        setupLink(for: channel, peripheral: peripheral)
    }
}

// MARK: - CBPeripheralManagerDelegate (advertise, publish the channel, serve the PSM)

extension NearbyManager: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        guard peripheral.state == .poweredOn else {
            print("nearby peripheral state \(peripheral.state.rawValue)")
            return
        }
        if !didAddService {
            didAddService = true
            let characteristic = CBMutableCharacteristic(type: portCharacteristicID,
                                                         properties: [.read], value: nil,
                                                         permissions: [.readable])
            let service = CBMutableService(type: serviceID, primary: true)
            service.characteristics = [characteristic]
            peripheral.add(service)
            peripheral.publishL2CAPChannel(withEncryption: false)
        }
        beginAdvertising()
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
        guard error == nil, let channel, !paused else { return }
        setupLink(for: channel, peripheral: nil)
    }
}

// MARK: - StreamDelegate (per-link byte I/O)

extension NearbyManager: StreamDelegate {
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        guard let link = links[ObjectIdentifier(aStream)] else { return }
        switch eventCode {
        case .hasBytesAvailable:
            receive(on: link)
        case .openCompleted, .hasSpaceAvailable:
            if aStream === link.output {
                queueOutgoing(on: link)
                flush(link)
            }
        case .errorOccurred, .endEncountered:
            tearDownLink(link)
        default:
            break
        }
    }
}
