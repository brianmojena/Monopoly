import Foundation
import MultipeerConnectivity

final class MultipeerGameTransport: NSObject, GameTransport {
    let localPeerID: PeerID

    var onDataReceived: ((Data, PeerID) -> Void)?
    var onPeerConnected: ((PeerID) -> Void)?
    var onPeerDisconnected: ((PeerID) -> Void)?
    var onPeerFound: ((PeerID, [String: String]) -> Void)?
    var onPeerLost: ((PeerID) -> Void)?

    private let peer: MCPeerID
    private let serviceType: String
    private let session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser
    private let browser: MCNearbyServiceBrowser
    private var isAdvertising = false
    private var discoveryInfo: [String: String]?
    private var advertisedInfo: [String: String]?
    private var pendingAdvertisementUpdate: DispatchWorkItem?
    // Browser callbacks arrive on MultipeerConnectivity's own queue while invites
    // come from the UI, so the found-peer table is guarded by a lock.
    private let foundPeersLock = NSLock()
    private var foundPeers: [PeerID: MCPeerID] = [:]

    init(displayName: String, serviceType: String = "monopoly-game") {
        let peer = MCPeerID(displayName: displayName)
        self.peer = peer
        self.serviceType = serviceType
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
        isAdvertising = true
        advertiser.startAdvertisingPeer()
    }

    func startBrowsing() {
        browser.startBrowsingForPeers()
    }

    // Discovery info is fixed per advertiser, so a change means restarting it. The
    // restart is debounced because the host's name changes on every keystroke in
    // the lobby, and each restart makes browsers drop and re-find the room.
    func updateDiscoveryInfo(_ info: [String: String]) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.updateDiscoveryInfo(info)
            }
            return
        }
        guard info != discoveryInfo else {
            return
        }
        discoveryInfo = info

        pendingAdvertisementUpdate?.cancel()
        guard advertisedInfo != nil else {
            restartAdvertiser()
            return
        }
        let update = DispatchWorkItem { [weak self] in
            self?.restartAdvertiser()
        }
        pendingAdvertisementUpdate = update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: update)
    }

    func invite(_ peer: PeerID) {
        let mcPeer = foundPeersLock.withLock { foundPeers[peer] }
        guard let mcPeer else {
            return
        }
        browser.invitePeer(mcPeer, to: session, withContext: nil, timeout: 30)
    }

    func disconnect() {
        session.disconnect()
    }

    func stop() {
        pendingAdvertisementUpdate?.cancel()
        isAdvertising = false
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        session.disconnect()
    }

    private func restartAdvertiser() {
        advertisedInfo = discoveryInfo
        advertiser.stopAdvertisingPeer()
        advertiser = MCNearbyServiceAdvertiser(
            peer: peer,
            discoveryInfo: discoveryInfo,
            serviceType: serviceType
        )
        advertiser.delegate = self
        if isAdvertising {
            advertiser.startAdvertisingPeer()
        }
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
        let mappedPeerID = PeerID(rawValue: peerID.displayName)
        foundPeersLock.withLock { foundPeers[mappedPeerID] = peerID }
        onPeerFound?(mappedPeerID, info ?? [:])
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        let mappedPeerID = PeerID(rawValue: peerID.displayName)
        foundPeersLock.withLock { foundPeers[mappedPeerID] = nil }
        onPeerLost?(mappedPeerID)
    }

    func browser(
        _ browser: MCNearbyServiceBrowser,
        didNotStartBrowsingForPeers error: Error
    ) {
    }
}
