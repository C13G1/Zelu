//
//  MultipeerManager.swift
//  ConexoesAmizaticas
//
//  Created by Thomas Pinheiro Grandin on 02/06/26.
//

import MultipeerConnectivity

class MultipeerManager: NSObject, MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .connected:
            let encoder = JSONEncoder()
            do {
                let data = try encoder.encode(self.profile)
                print("sending user data!")
                try session.send(data, toPeers: [], with: .reliable)
                self.targeIDs.remove(peerID.displayName)
            }
            catch { print(error) }
        default:
            print("deu errado na troca de estado da MCSession")
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            let data = try JSONDecoder().decode(User.self, from: data)
            print("user data received!")
            if let onFriendDataReceived = onFriendDataReceived {
                onFriendDataReceived(data)
            }
        }
        catch { print(error) }
    }
    
    private var profile: User
    private let serviceType = "conn-amiza"
    private var myPeerId: MCPeerID
    var session: MCSession
    
    private var browser: MCNearbyServiceBrowser?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var targeIDs: Set<String> = []
    var onFriendDataReceived: ((User) -> Void)?
    
    init(profile: User) {
        self.profile = profile
        self.myPeerId = MCPeerID(displayName: profile.id.uuidString)
        self.session = MCSession(peer: myPeerId, securityIdentity: nil, encryptionPreference: .required)
        super.init()
        self.session.delegate = self
    }
    
    /// Essa é a função que o BLE vai chamar
    func conectar(userID: String) {
        print("conectando com multipeer")
        self.targeIDs.insert(userID)
        if self.browser == nil || self.advertiser == nil { ligarAntenas() }
        print("Multipeer ativado. Procurando o usuário \(userID)")
    }
    
    private func ligarAntenas() {
        self.browser = MCNearbyServiceBrowser(peer: myPeerId, serviceType: serviceType)
        self.browser?.delegate = self
        self.browser?.startBrowsingForPeers()
        
        self.advertiser = MCNearbyServiceAdvertiser(peer: myPeerId, discoveryInfo: nil, serviceType: serviceType)
        self.advertiser?.delegate = self
        self.advertiser?.startAdvertisingPeer()
        print("Multipeer ativado. Procurando usuários...")
    }
    
    private func desligarAntenas() {
        self.browser?.stopBrowsingForPeers()
        self.advertiser?.stopAdvertisingPeer()
        print("Multipeer desativado.")
    }
    
    func desligar() {
        browser?.stopBrowsingForPeers()
        session.disconnect()
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: (any Error)?) {}
}

extension MultipeerManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        if self.targeIDs.contains(peerID.displayName) {
            print("Alvo encontrado via Wi-Fi Direct! Conectando...")
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
        }
        else {
            print("erro na descoberta de \(peerID.displayName)")
        }
    }
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}

extension MultipeerManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        
        if self.targeIDs.contains(peerID.displayName) {
            print("Convite recebido de \(peerID.displayName) (está na lista). Aceitando...")
            invitationHandler(true, self.session)
        } else {
            print("invitation deu errado")
            invitationHandler(false, nil)
        }
    }
}
