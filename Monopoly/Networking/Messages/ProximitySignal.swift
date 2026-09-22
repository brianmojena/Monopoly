import Foundation

struct ProximitySignal: Codable, Equatable {
    enum Kind: String, Codable {
        case invite
        case accept
        case decline
        case unsupported
        case cancel
    }

    let sessionID: UUID
    let kind: Kind
    let senderPlayerID: UUID
    let recipientPlayerID: UUID
    let discoveryToken: Data?

    init(
        sessionID: UUID,
        kind: Kind,
        senderPlayerID: UUID,
        recipientPlayerID: UUID,
        discoveryToken: Data? = nil
    ) {
        self.sessionID = sessionID
        self.kind = kind
        self.senderPlayerID = senderPlayerID
        self.recipientPlayerID = recipientPlayerID
        self.discoveryToken = discoveryToken
    }
}
