import Foundation

struct PeerID: Codable, Equatable, Hashable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(_ rawValue: String) {
        self.init(rawValue: rawValue)
    }
}

enum GameTransportError: Error, Equatable {
    case peerNotConnected(PeerID)
}

protocol GameTransport: AnyObject {
    var localPeerID: PeerID { get }
    var onDataReceived: ((Data, PeerID) -> Void)? { get set }
    var onPeerConnected: ((PeerID) -> Void)? { get set }
    var onPeerDisconnected: ((PeerID) -> Void)? { get set }

    func send(data: Data, to peer: PeerID) throws
    func broadcast(data: Data) throws
    func startHosting()
    func startBrowsing()
    func stop()
}
