//
//  NearbyManager.swift
//  ConexoesAmizaticas
//
//  Created by Enzo Ferroni on 09/06/26.
//

import Foundation
import MultipeerConnectivity
import UIKit

/// A person discovered nearby. Appears with the name first and receives the photo a moment later.
/// The invite flags tell the radar what to show for this person.
struct NearbyPerson: Identifiable, Equatable {
    var user: User
    var hasPhoto: Bool
    var sentInvite: Bool = false
    var receivedInvite: Bool = false
    /// How close this person is, from 0 to 1 (1 = right next to you). The radar uses this to pick
    /// the ring. Fed by the Bluetooth distance estimate of `NearbyProximityScanner`; stays at the
    /// neutral 0.5 while no reading arrived.
    var proximity: Double = 0.5

    var id: UUID { user.id }

    static func == (lhs: NearbyPerson, rhs: NearbyPerson) -> Bool {
        lhs.user.id == rhs.user.id && lhs.hasPhoto == rhs.hasPhoto
            && lhs.sentInvite == rhs.sentInvite && lhs.receivedInvite == rhs.receivedInvite
            && lhs.proximity == rhs.proximity
    }
}

/// Discovers every nearby app user and keeps the `people` list up to date.
///
/// Built on `MultipeerConnectivity`, which handles the discovery, the connections and the message
/// delivery. Each device announces itself with its name and id while searching for others. Found
/// devices connect automatically and exchange their photos. When two people invite each other,
/// `onMutualMatch` fires and the pair leaves the radar of everyone else during the meeting.
@Observable
final class NearbyManager: NSObject {

    /// DISTANCE LIMIT OF THE RADAR, in meters. People estimated farther than this do not appear.
    ///
    /// This is the number to play with: 5 keeps only people right around you, 10 covers a small
    /// room, 15 a classroom, 30 a whole floor. It also calibrates the rings — someone right next
    /// to you lands on the inner ring and someone at this limit on the outer one.
    ///
    /// The distance comes from the Bluetooth signal strength and is a rough estimate: walls,
    /// pockets and bodies in between make people look farther than they are. People whose
    /// distance could not be measured yet always appear (middle ring).
    static let maxVisibleDistanceMeters: Double = 15

    /// The people currently nearby. Bound directly to the grid.
    private(set) var people: [NearbyPerson] = []

    /// Fired once when this device and a peer have invited each other.
    var onMutualMatch: ((User) -> Void)?

    /// This device's profile, shared with every peer.
    let profile: User

    /// `profile.id` saved as plain text. `User` is a SwiftData model and can only be read on the
    /// main thread, so the MultipeerConnectivity callbacks use this copy instead.
    private let ownID: String

    /// Name of the service announced on the local network. Must match the `NSBonjourServices`
    /// entry in Info.plist.
    private let serviceType = "conexoes-near"

    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    /// Measures, over Bluetooth, how far each discovered person is.
    private let proximityScanner: NearbyProximityScanner
    /// True between `pauseForMeeting()` and `resume()`.
    private var paused = false

    /// Everything we know about one discovered peer.
    private final class Peer {
        var user: User
        var hasPhoto = false
        var iInvited = false
        var theyInvited = false
        var isMock = false
        var didMatch = false
        var proximity: Double = 0.5
        /// Last estimated distance in meters. Stays nil while no Bluetooth reading arrived.
        var distanceMeters: Double?
        init(user: User) { self.user = user }
    }

    private var peers: [MCPeerID: Peer] = [:]

    /// True when MultipeerConnectivity refused to start browsing or advertising — almost always the
    /// Local Network permission being denied (the radar can't find anyone without it). Drives the
    /// "ligue a rede local" guidance on screen.
    private(set) var discoveryUnavailable = false

    /// True after browsing has run for a while without finding anyone. Multipeer does NOT reliably
    /// report a denied Local Network permission, so an empty radar is ambiguous: nobody around, or a
    /// radio/permission is off. This drives a soft hint telling the user what to check — without
    /// claiming a specific cause. Cleared the moment a peer shows up.
    private(set) var searchedWithoutResults = false

    /// Fires once `searchHintDelay` after browsing starts to raise `searchedWithoutResults`.
    private var searchHintTimer: Timer?
    private static let searchHintDelay: TimeInterval = 10

    private func startSearchHintTimer() {
        searchHintTimer?.invalidate()
        searchedWithoutResults = false
        searchHintTimer = Timer.scheduledTimer(withTimeInterval: Self.searchHintDelay, repeats: false) { [weak self] _ in
            guard let self, !self.paused else { return }
            if self.people.isEmpty { self.searchedWithoutResults = true }
        }
    }

    private func stopSearchHintTimer() {
        searchHintTimer?.invalidate()
        searchHintTimer = nil
        searchedWithoutResults = false
    }

    /// Invite state kept by `user.id` so it survives a reconnect. A dropped peer comes back under a
    /// fresh `MCPeerID` with its `Peer` rebuilt from scratch; without this, an invite sent before the
    /// drop was forgotten and the other side never matched ("mandou o convite e a pessoa não recebe").
    private var savedInvites: [UUID: (iInvited: Bool, theyInvited: Bool)] = [:]

    /// Restores any remembered invite flags onto a freshly created peer.
    private func restoreInvites(_ peer: Peer) {
        if let saved = savedInvites[peer.user.id] {
            peer.iInvited = saved.iInvited
            peer.theyInvited = saved.theyInvited
        }
    }

    init(profile: User) {
        self.profile = profile
        self.ownID = profile.id.uuidString
        self.proximityScanner = NearbyProximityScanner(ownID: profile.id.uuidString)
        super.init()
    }

    // MARK: - Messages

    /// One message between two devices. Each `send` arrives as one `didReceive` on the other side.
    /// The `profile` message carries name and id, so the other side can register us even when it
    /// never discovered us by itself.
    private struct Packet: Codable {
        enum Kind: String, Codable { case profile, profileRequest, invite, cancel }
        let kind: Kind
        var photo: Data? = nil
        var name: String? = nil
        var userID: UUID? = nil
    }

    private func profilePacket() -> Packet {
        Packet(kind: .profile, photo: compressedPhoto(), name: profile.name, userID: profile.id)
    }

    // MARK: - Lifecycle

    /// Starts advertising and browsing. Safe to call repeatedly.
    func start() {
        guard session == nil else { return }
        print("nearby start")
        paused = false
        discoveryUnavailable = false
        let peerID = MCPeerID(displayName: profile.id.uuidString)
        let session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .none)
        session.delegate = self
        self.session = session

        let advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: ["n": profile.name, "u": profile.id.uuidString],
            serviceType: serviceType
        )
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        self.advertiser = advertiser

        let browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
        self.browser = browser

        proximityScanner.onDistanceReading = { [weak self] userID, meters in
            self?.updateDistance(userIDStart: userID, meters: meters)
        }
        proximityScanner.start()
        startSearchHintTimer()
    }

    /// Turns everything off. Call when the screen is left.
    func stop() {
        print("nearby stop")
        stopSearchHintTimer()
        proximityScanner.stop()
        teardownAdvertiser()
        teardownBrowser()
        session?.delegate = nil
        session?.disconnect()
        session = nil
        paused = false
        discoveryUnavailable = false
        peers.removeAll()
        savedInvites.removeAll()
        people.removeAll()
    }

    /// Detaches the delegate before stopping, then releases the browser. Discovery callbacks arrive
    /// on a background thread, so stopping (or deallocating) the browser while one is in flight races
    /// the underlying Bonjour cancel and crashed inside `_BrowserCancel`. Nil-ing the delegate first
    /// guarantees no callback lands on a browser that is being torn down.
    private func teardownBrowser() {
        browser?.delegate = nil
        browser?.stopBrowsingForPeers()
        browser = nil
    }

    private func teardownAdvertiser() {
        advertiser?.delegate = nil
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
    }

    /// After a mutual invite, hides the pair from everyone else during the meeting. The disconnect
    /// waits half a second so the last invite message is delivered first.
    func pauseForMeeting() {
        print("nearby pause (meeting)")
        paused = true
        stopSearchHintTimer()
        proximityScanner.stop()
        teardownAdvertiser()
        teardownBrowser()
        people.removeAll()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, self.paused else { return }
            self.session?.disconnect()
        }
    }

    /// Back from the meeting. Starts everything again from zero.
    func resume() {
        stop()
        start()
    }

    /// Restarts the search, so people seen before can be found again. Tears the old browser down
    /// fully and builds a fresh one rather than stopping and immediately restarting the same object:
    /// re-arming a browser mid-cancel re-enters the underlying Bonjour browser while it is tearing
    /// down, which crashed inside `_BrowserCancel`. A new browser gets its own clean state.
    private func restartBrowsing() {
        guard !paused, let session else { return }
        teardownBrowser()
        let browser = MCNearbyServiceBrowser(peer: session.myPeerID, serviceType: serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
        self.browser = browser
    }

    // MARK: - Distance

    /// Applies a fresh Bluetooth distance reading to the matching peer. The announced id can
    /// arrive cut short, so it is matched as the beginning of the full peer id.
    private func updateDistance(userIDStart: String, meters: Double) {
        guard userIDStart.count >= 8,
              let peer = peers.first(where: { $0.key.displayName.hasPrefix(userIDStart) })?.value
        else { return }

        let wasVisible = peer.distanceMeters.map { $0 <= Self.maxVisibleDistanceMeters } ?? true
        let previousMeters = peer.distanceMeters
        peer.distanceMeters = meters
        // Closeness used by the rings: 1 right next to you, 0 at the visibility limit.
        peer.proximity = max(0, min(1, 1 - meters / Self.maxVisibleDistanceMeters))

        // Readings arrive several times per second. Only redraw the radar when the person
        // appeared, disappeared or moved a noticeable amount.
        let isVisible = meters <= Self.maxVisibleDistanceMeters
        if wasVisible != isVisible || abs((previousMeters ?? .zero) - meters) > 0.5 {
            rebuildGrid()
        }
    }

    // MARK: - Grid

    /// Updates the `people` list shown on screen, closest people first. People measured farther
    /// than `maxVisibleDistanceMeters` are left out. Called after any change.
    private func rebuildGrid() {
        // One entry per person. The same person can reconnect under a new `MCPeerID` (a fresh object
        // with the same display name), leaving two dict entries with the same `user.id`. Two grid
        // cells with the same id crash the radar's `ForEach`, so collapse duplicates here.
        var seen = Set<UUID>()
        people = peers
            .compactMap { (peerID, peer) -> NearbyPerson? in
                // Only show a person once we are actually connected and ready to exchange data
                // (mocks aside). Mirrors the BLE flow: nobody shows while the connection is still
                // coming up, which also keeps half-open peers out of the grid.
                guard peer.isMock || session?.connectedPeers.contains(peerID) == true else { return nil }
                // Without a reading the person stays visible: the estimate may never come, for
                // example when Bluetooth is off on either side.
                if let meters = peer.distanceMeters, meters > Self.maxVisibleDistanceMeters { return nil }
                guard seen.insert(peer.user.id).inserted else { return nil }
                return NearbyPerson(user: peer.user, hasPhoto: peer.hasPhoto,
                                    sentInvite: peer.iInvited, receivedInvite: peer.theyInvited,
                                    proximity: peer.proximity)
            }
            .sorted {
                if $0.proximity != $1.proximity { return $0.proximity > $1.proximity }
                return $0.user.name.localizedCaseInsensitiveCompare($1.user.name) == .orderedAscending
            }

        // Someone is on the radar, so neither the "found nobody" hint nor the discovery-failed flag
        // apply anymore.
        if !people.isEmpty {
            searchedWithoutResults = false
            discoveryUnavailable = false
        }
    }

    // MARK: - Invites

    /// Toggles a meeting invite to the tapped person. When both sides have invited, fires `onMutualMatch`.
    func toggleInvite(_ userID: UUID) {
        guard let (peerID, peer) = peers.first(where: { $0.value.user.id == userID }) else { return }
        #if DEBUG
        if peer.isMock { onMutualMatch?(peer.user); return }
        #endif
        peer.iInvited.toggle()
        savedInvites[peer.user.id] = (peer.iInvited, peer.theyInvited)
        send(Packet(kind: peer.iInvited ? .invite : .cancel), to: peerID)
        rebuildGrid()
        checkMutual(peerID, peer)
    }

    private func checkMutual(_ peerID: MCPeerID, _ peer: Peer) {
        guard peer.iInvited, peer.theyInvited, !peer.didMatch else { return }
        peer.didMatch = true
        print("nearby mutual match: \(peer.user.name)")
        onMutualMatch?(peer.user)
    }

    // MARK: - Send / receive

    private func send(_ packet: Packet, to peerID: MCPeerID) {
        guard let session, let data = try? JSONEncoder().encode(packet) else { return }
        try? session.send(data, toPeers: [peerID], with: .reliable)
    }

    private func handle(_ packet: Packet, from peerID: MCPeerID) {
        // A profile can arrive from someone we never discovered ourselves. Register them here,
        // so whoever can see us is always seen by us too.
        if peers[peerID] == nil, packet.kind == .profile, let name = packet.name, let id = packet.userID {
            let peer = Peer(user: User(name: name, profilePicture: Data(), id: id))
            restoreInvites(peer)
            peers[peerID] = peer
        }
        guard let peer = peers[peerID] else { return }
        switch packet.kind {
        case .profile:
            if let photo = packet.photo {
                peer.user = User(name: peer.user.name, profilePicture: photo, id: peer.user.id)
                peer.hasPhoto = true
            }
        case .profileRequest:
            send(profilePacket(), to: peerID)
        case .invite:
            peer.theyInvited = true
            savedInvites[peer.user.id] = (peer.iInvited, peer.theyInvited)
        case .cancel:
            peer.theyInvited = false
            savedInvites[peer.user.id] = (peer.iInvited, peer.theyInvited)
        }
        rebuildGrid()
        checkMutual(peerID, peer)
    }

    /// The photo can get lost when the connection opens at the edge of the range. While it has
    /// not arrived, asks for the profile again, up to 3 times.
    private func schedulePhotoRetry(for peerID: MCPeerID, attempt: Int = 1) {
        guard attempt <= 3 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(4 * attempt)) { [weak self] in
            guard let self, let peer = self.peers[peerID], !peer.hasPhoto,
                  self.session?.connectedPeers.contains(peerID) == true else { return }
            self.send(Packet(kind: .profileRequest), to: peerID)
            self.schedulePhotoRetry(for: peerID, attempt: attempt + 1)
        }
    }

    /// Our profile photo, squared down to a small JPEG so it transfers quickly.
    private func compressedPhoto() -> Data {
        if let image = UIImage(data: profile.profilePicture),
           let thumb = image.squareThumbnail(side: 256)
               .jpegData(compressionQuality: 0.7) {
            return thumb
        }
        return profile.profilePicture
    }

    #if DEBUG
    /// Counts the batches of fake people already added, to keep their names unique.
    private var mockBatch = 0

    /// Adds five fake people to the radar so the UI can be tested on a single device. Every call
    /// adds a new batch, so tapping the button repeatedly tests a crowded radar.
    func injectMockPeople() {
        mockBatch += 1
        let suffix = mockBatch == 1 ? "" : " \(mockBatch)"
        let picture = UIImage(named: "defaultPicture")?.jpegData(compressionQuality: 0.8) ?? Data()
        for (name, proximity) in [("Osmar", 0.4), ("Ed Sheeran", 0.4), ("Laura", 0.4),
                                  ("Juliana", 0.35), ("Thais", 0.15)] {
            let peerID = MCPeerID(displayName: name + suffix)
            guard peers[peerID] == nil else { continue }
            let peer = Peer(user: User(name: name + suffix, profilePicture: picture))
            peer.hasPhoto = true
            peer.isMock = true
            peer.proximity = proximity
            peers[peerID] = peer
        }
        rebuildGrid()
    }
    #endif
}

// MARK: - MCNearbyServiceBrowserDelegate (discovery)

extension NearbyManager: MCNearbyServiceBrowserDelegate {
    // These callbacks arrive on a background thread. Every handler moves to the main thread first,
    // because `peers`, `people` and the SwiftData models can only be touched there.
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID,
                 withDiscoveryInfo info: [String: String]?) {
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.paused, self.peers[peerID] == nil,
                  let name = info?["n"], let idString = info?["u"], let id = UUID(uuidString: idString)
            else { return }
            // Discovery is clearly working (we found someone), so any earlier "couldn't start" flag
            // was transient — clear it.
            self.discoveryUnavailable = false
            let peer = Peer(user: User(name: name, profilePicture: Data(), id: id))
            self.restoreInvites(peer)
            self.peers[peerID] = peer
            self.rebuildGrid()
            // Only the side with the smaller id invites and the other accepts, keeping a single
            // connection per pair.
            if self.ownID < peerID.displayName, let session = self.session {
                self.browser?.invitePeer(peerID, to: session, withContext: nil, timeout: 15)
            } else {
                // The other side may have never found us. If nothing connected after a while,
                // invite from this side too so the pair still connects.
                DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
                    guard let self, !self.paused, self.peers[peerID] != nil,
                          self.session?.connectedPeers.contains(peerID) != true,
                          let session = self.session else { return }
                    self.browser?.invitePeer(peerID, to: session, withContext: nil, timeout: 15)
                }
            }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        // Fired when browsing can't start — almost always Local Network permission denied. Flag it so
        // the screen can tell the user to enable it; without it nobody is ever discovered.
        print("nearby browse failed: \(error.localizedDescription)")
        DispatchQueue.main.async { [weak self] in self?.discoveryUnavailable = true }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // The search sometimes reports a lost person by mistake. While the connection is
            // alive, the person is still there.
            guard self.session?.connectedPeers.contains(peerID) != true else { return }
            self.peers[peerID] = nil
            self.rebuildGrid()
        }
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate (accept connections)

extension NearbyManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        DispatchQueue.main.async { [weak self] in
            // Accepting without a session crashes the app. It can happen when an invitation
            // arrives in the middle of a stop, so decline instead.
            guard let self, let session = self.session, !self.paused else {
                invitationHandler(false, nil)
                return
            }
            invitationHandler(true, session)
        }
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        // Same story as the browser: usually Local Network permission denied. Surface it so the user
        // can fix it instead of staring at an empty radar.
        print("nearby advertise failed: \(error.localizedDescription)")
        DispatchQueue.main.async { [weak self] in self?.discoveryUnavailable = true }
    }
}

// MARK: - MCSessionDelegate (connection state + messages)

extension NearbyManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch state {
            case .connected:
                // Ready to exchange data now, so the person can appear on the radar.
                self.rebuildGrid()
                // Send our photo so the placeholder upgrades to the real picture.
                self.send(self.profilePacket(), to: peerID)
                self.schedulePhotoRetry(for: peerID)
                // Re-assert a standing invite after a reconnect, so a peer that dropped and came back
                // still sees it and the pair can match.
                if let peer = self.peers[peerID], peer.iInvited {
                    self.send(Packet(kind: .invite), to: peerID)
                    self.checkMutual(peerID, peer)
                }
            case .notConnected:
                self.peers[peerID] = nil
                self.rebuildGrid()
                // Multipeer only reports each found person once per search. Restart the search so
                // anyone still around is found and connected again.
                self.restartBrowsing()
            default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let packet = try? JSONDecoder().decode(Packet.self, from: data) else { return }
        DispatchQueue.main.async { [weak self] in self?.handle(packet, from: peerID) }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}
