//
//  NearbyManager.swift
//  ConexoesAmizaticas
//
//  Created by Enzo Ferroni on 09/06/26.
//

import Foundation
import MultipeerConnectivity
import UIKit

/// A person discovered nearby, as shown in the "Pessoas por perto" grid. Appears name-only first
/// (`hasPhoto == false`) and gets its photo a moment later. The invite flags drive the tap-to-meet UI.
struct NearbyPerson: Identifiable, Equatable {
    var user: User
    var hasPhoto: Bool
    var sentInvite: Bool = false
    var receivedInvite: Bool = false

    var id: UUID { user.id }

    static func == (lhs: NearbyPerson, rhs: NearbyPerson) -> Bool {
        lhs.user.id == rhs.user.id && lhs.hasPhoto == rhs.hasPhoto
            && lhs.sentInvite == rhs.sentInvite && lhs.receivedInvite == rhs.receivedInvite
    }
}

/// Discovers every nearby app user and drives the "Pessoas por perto" grid.
///
/// Built on `MultipeerConnectivity`, which handles the discovery, connections and message delivery for
/// us. Each device advertises (carrying its name and id) and browses; found peers connect automatically
/// and send their photo. Tapping a person sends an invite — when two people invite each other
/// (`onMutualMatch`) they head to the meeting and disconnect, disappearing from the other grids.
@Observable
final class NearbyManager: NSObject {

    /// The people currently nearby. Bound directly to the grid.
    private(set) var people: [NearbyPerson] = []

    /// Fired once when this device and a peer have invited each other.
    var onMutualMatch: ((User) -> Void)?

    /// This device's profile, shared with every peer.
    let profile: User

    /// Bonjour-style service name; must match the peer app and the `NSBonjourServices` in Info.plist.
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
        init(user: User) { self.user = user }
    }

    private var peers: [MCPeerID: Peer] = [:]

    init(profile: User) {
        self.profile = profile
        super.init()
    }

    // MARK: - Messages

    /// One discrete message between peers. MultipeerConnectivity delivers each `send` as one `didReceive`.
    private struct Packet: Codable {
        enum Kind: String, Codable { case profile, invite, cancel }
        let kind: Kind
        var photo: Data? = nil
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

    /// Full teardown — call when the grid screen is left.
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

    /// On a mutual match: stop being discoverable and disconnect (after a beat, so the final invite is
    /// delivered first) so the pair disappears from other grids during the meeting.
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

    /// Back from the meeting — rebuild everything fresh.
    func resume() {
        stop()
        start()
    }

    // MARK: - Grid

    /// Rebuilds the published grid from the peer table. Called after any change.
    private func rebuildGrid() {
        people = peers.values
            .map { NearbyPerson(user: $0.user, hasPhoto: $0.hasPhoto,
                                sentInvite: $0.iInvited, receivedInvite: $0.theyInvited) }
            .sorted { $0.user.name.localizedCaseInsensitiveCompare($1.user.name) == .orderedAscending }
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
        guard let peer = peers[peerID] else { return }
        switch packet.kind {
        case .profile:
            if let photo = packet.photo {
                peer.user = User(name: peer.user.name, profilePicture: photo, id: peer.user.id)
                peer.hasPhoto = true
            }
        case .invite:
            peer.theyInvited = true
        case .cancel:
            peer.theyInvited = false
        }
        rebuildGrid()
        checkMutual(peerID, peer)
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
        for name in ["Osmar", "Ed Sheeran", "Laura", "Juliana", "Thais"] {
            let peerID = MCPeerID(displayName: name)
            guard peers[peerID] == nil else { continue }
            let peer = Peer(user: User(name: name, profilePicture: picture))
            peer.hasPhoto = true
            peer.isMock = true
            peers[peerID] = peer
        }
        rebuildGrid()
    }
    #endif
}

// MARK: - MCNearbyServiceBrowserDelegate (discovery)

extension NearbyManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID,
                 withDiscoveryInfo info: [String: String]?) {
        guard !paused, peers[peerID] == nil,
              let name = info?["n"], let idString = info?["u"], let id = UUID(uuidString: idString)
        else { return }
        peers[peerID] = Peer(user: User(name: name, profilePicture: Data(), id: id))
        rebuildGrid()
        // Tie-breaker so only one side invites; the other auto-accepts. One connection per pair.
        if profile.id.uuidString < peerID.displayName, let session {
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 15)
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        peers[peerID] = nil
        rebuildGrid()
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate (accept connections)

extension NearbyManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(!paused, session)
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
                self.send(Packet(kind: .profile, photo: self.compressedPhoto()), to: peerID)
            case .notConnected:
                self.peers[peerID] = nil
                self.rebuildGrid()
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
