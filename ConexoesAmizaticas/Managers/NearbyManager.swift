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
    /// the ring. MultipeerConnectivity gives no signal strength, so for now everyone stays at the
    /// neutral 0.5 until a real source (like a Bluetooth signal read) feeds it.
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
    /// True between `pauseForMeeting()` and `resume()`.
    private var paused = false

    /// Everything we know about one discovered peer.
    private final class Peer {
        var user: User
        var hasPhoto = false
        var iInvited = false
        var theyInvited = false
        var didMatch = false
        var isMock = false
        var proximity: Double = 0.5
        init(user: User) { self.user = user }
    }

    private var peers: [MCPeerID: Peer] = [:]

    init(profile: User) {
        self.profile = profile
        self.ownID = profile.id.uuidString
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
    }

    /// Turns everything off. Call when the screen is left.
    func stop() {
        print("nearby stop")
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        advertiser = nil
        browser = nil
        session = nil
        paused = false
        peers.removeAll()
        people.removeAll()
    }

    /// After a mutual invite, hides the pair from everyone else during the meeting. The disconnect
    /// waits half a second so the last invite message is delivered first.
    func pauseForMeeting() {
        print("nearby pause (meeting)")
        paused = true
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
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

    /// Stops and restarts the search, so people seen before can be found again.
    private func restartBrowsing() {
        guard !paused, let browser else { return }
        browser.stopBrowsingForPeers()
        browser.startBrowsingForPeers()
    }

    // MARK: - Grid

    /// Updates the `people` list shown on screen, closest people first. Called after any change.
    private func rebuildGrid() {
        people = peers.values
            .map { NearbyPerson(user: $0.user, hasPhoto: $0.hasPhoto,
                                sentInvite: $0.iInvited, receivedInvite: $0.theyInvited,
                                proximity: $0.proximity) }
            .sorted {
                if $0.proximity != $1.proximity { return $0.proximity > $1.proximity }
                return $0.user.name.localizedCaseInsensitiveCompare($1.user.name) == .orderedAscending
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
            peers[peerID] = Peer(user: User(name: name, profilePicture: Data(), id: id))
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
        case .cancel:
            peer.theyInvited = false
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
           let thumb = image.preparingThumbnail(of: CGSize(width: 256, height: 256))?
               .jpegData(compressionQuality: 0.7) {
            return thumb
        }
        return profile.profilePicture
    }

    #if DEBUG
    /// Seeds the grid with fake people so the UI can be exercised on a single device.
    func injectMockPeople() {
        let picture = UIImage(named: "defaultPicture")?.jpegData(compressionQuality: 0.8) ?? Data()
        for (name, proximity) in [("Osmar", 0.4), ("Ed Sheeran", 0.4), ("Laura", 0.4),
                                  ("Juliana", 0.35), ("Thais", 0.15)] {
            let peerID = MCPeerID(displayName: name)
            guard peers[peerID] == nil else { continue }
            let peer = Peer(user: User(name: name, profilePicture: picture))
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
            self.peers[peerID] = Peer(user: User(name: name, profilePicture: Data(), id: id))
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
}

// MARK: - MCSessionDelegate (connection state + messages)

extension NearbyManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch state {
            case .connected:
                // Send our photo so the placeholder upgrades to the real picture.
                self.send(self.profilePacket(), to: peerID)
                self.schedulePhotoRetry(for: peerID)
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
