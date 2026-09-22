import Foundation
import MultipeerConnectivity

final class MultipeerGameTransport: NSObject, GameTransport {
    let localPeerID: PeerID

    var onDataReceived: ((Data, PeerID) -> Void)?
    var onPeerConnected: ((PeerID) -> Void)?
    var onPeerDisconnected: ((PeerID) -> Void)?

    private let peer: MCPeerID
    private let session: MCSession
    private let advertiser: MCNearbyServiceAdvertiser
    private let browser: MCNearbyServiceBrowser

    init(displayName: String, serviceType: String = "monopoly-game") {
        let peer = MCPeerID(displayName: displayName)
        self.peer = peer
        self.localPeerID = PeerID(rawValue: displayName)
        self.session = MCSession(
            peer: peer,
            securityIdentity: nil,
            encryptionPreference: .required
        )
        self.advertiser = MCNearbyServiceAdvertiser(
            peer: peer,
            discoveryInfo: nil,
            serviceType: serviceType
        )
        self.browser = MCNearbyServiceBrowser(peer: peer, serviceType: serviceType)
        super.init()

        session.delegate = self
        advertiser.delegate = self
        browser.delegate = self
    }

    func send(data: Data, to peer: PeerID) throws {
        guard let destination = session.connectedPeers.first(where: {
            PeerID(rawValue: $0.displayName) == peer
        }) else {
            throw GameTransportError.peerNotConnected(peer)
        }

        try session.send(data, toPeers: [destination], with: .reliable)
    }

    func broadcast(data: Data) throws {
        guard !session.connectedPeers.isEmpty else {
            return
        }

        try session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }

    func startHosting() {
        advertiser.startAdvertisingPeer()
    }

    func startBrowsing() {
        browser.startBrowsingForPeers()
    }

    func stop() {
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        session.disconnect()
    }
}

@available(iOS, deprecated: 27.0, message: "MultipeerConnectivity is required by the project's local-network architecture.")
extension MultipeerGameTransport: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        let mappedPeerID = PeerID(rawValue: peerID.displayName)
        switch state {
        case .connected:
            onPeerConnected?(mappedPeerID)
        case .notConnected:
            onPeerDisconnected?(mappedPeerID)
        case .connecting:
            break
        @unknown default:
            break
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        onDataReceived?(data, PeerID(rawValue: peerID.displayName))
    }

    func session(
        _ session: MCSession,
        didReceive stream: InputStream,
        withName streamName: String,
        fromPeer peerID: MCPeerID
    ) {
    }

    func session(
        _ session: MCSession,
        didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        with progress: Progress
    ) {
    }

    func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: Error?
    ) {
    }

    func session(
        _ session: MCSession,
        didReceive certificate: [Any]?,
        fromPeer peerID: MCPeerID,
        certificateHandler: @escaping (Bool) -> Void
    ) {
        certificateHandler(true)
    }
}

@available(iOS, deprecated: 27.0, message: "MultipeerConnectivity is required by the project's local-network architecture.")
extension MultipeerGameTransport: MCNearbyServiceAdvertiserDelegate {
    func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        invitationHandler(true, session)
    }

    func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didNotStartAdvertisingPeer error: Error
    ) {
    }
}

@available(iOS, deprecated: 27.0, message: "MultipeerConnectivity is required by the project's local-network architecture.")
extension MultipeerGameTransport: MCNearbyServiceBrowserDelegate {
    func browser(
        _ browser: MCNearbyServiceBrowser,
        foundPeer peerID: MCPeerID,
        withDiscoveryInfo info: [String: String]?
    ) {
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
    }

    func browser(
        _ browser: MCNearbyServiceBrowser,
        didNotStartBrowsingForPeers error: Error
    ) {
    }
}
