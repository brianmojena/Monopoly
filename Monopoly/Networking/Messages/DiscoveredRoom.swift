import Foundation

/// A game a host is advertising nearby, decoded from its Bonjour discovery info.
/// The info must stay small (Bonjour TXT records), so it carries only what the
/// room card shows.
struct DiscoveredRoom: Identifiable, Equatable {
    enum Phase: String {
        case lobby
        case playing
    }

    let id: UUID
    let peerID: PeerID
    let name: String
    let playerCount: Int
    let phase: Phase
    let round: Int
    let mode: GameMode

    // Single letters keep the Bonjour TXT record small.
    private static let classicCode = "c"
    private static let monopolifeCode = "l"

    private enum Key {
        static let room = "room"
        static let name = "name"
        static let players = "players"
        static let phase = "phase"
        static let round = "round"
        static let mode = "mode"
    }

    init?(peerID: PeerID, discoveryInfo info: [String: String]) {
        guard let id = info[Key.room].flatMap(UUID.init(uuidString:)),
              let phase = info[Key.phase].flatMap(Phase.init(rawValue:)) else {
            return nil
        }

        self.id = id
        self.peerID = peerID
        self.name = info[Key.name] ?? ""
        self.playerCount = info[Key.players].flatMap(Int.init) ?? 0
        self.phase = phase
        self.round = info[Key.round].flatMap(Int.init) ?? 1
        self.mode = info[Key.mode] == Self.monopolifeCode ? .monopolife : .classic
    }

    static func discoveryInfo(
        roomID: UUID,
        name: String,
        playerCount: Int,
        phase: Phase,
        round: Int,
        mode: GameMode = .classic
    ) -> [String: String] {
        [
            Key.room: roomID.uuidString,
            Key.name: String(name.prefix(40)),
            Key.players: String(playerCount),
            Key.phase: phase.rawValue,
            Key.round: String(round),
            Key.mode: mode == .monopolife ? monopolifeCode : classicCode
        ]
    }
}
