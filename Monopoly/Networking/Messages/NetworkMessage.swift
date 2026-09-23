import Foundation

enum NetworkMessage: Codable, Equatable {
    case intent(playerID: UUID, intent: GameIntent)
    case stateSnapshot(GameState)
    case intentRejected(GameRuleError)
    case proximitySignal(ProximitySignal)
    case lobbySnapshot(Lobby)
    case joinLobby(LobbyPlayer)

    private enum CodingKeys: String, CodingKey {
        case type
        case playerID
        case intent
        case state
        case error
        case signal
        case lobby
        case player
    }

    private enum MessageType: String, Codable {
        case intent
        case stateSnapshot
        case intentRejected
        case proximitySignal
        case lobbySnapshot
        case joinLobby
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(MessageType.self, forKey: .type)

        switch type {
        case .intent:
            self = .intent(
                playerID: try container.decode(UUID.self, forKey: .playerID),
                intent: try container.decode(GameIntent.self, forKey: .intent)
            )
        case .stateSnapshot:
            self = .stateSnapshot(try container.decode(GameState.self, forKey: .state))
        case .intentRejected:
            self = .intentRejected(try container.decode(GameRuleError.self, forKey: .error))
        case .proximitySignal:
            self = .proximitySignal(try container.decode(ProximitySignal.self, forKey: .signal))
        case .lobbySnapshot:
            self = .lobbySnapshot(try container.decode(Lobby.self, forKey: .lobby))
        case .joinLobby:
            self = .joinLobby(try container.decode(LobbyPlayer.self, forKey: .player))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .intent(playerID, intent):
            try container.encode(MessageType.intent, forKey: .type)
            try container.encode(playerID, forKey: .playerID)
            try container.encode(intent, forKey: .intent)
        case let .stateSnapshot(state):
            try container.encode(MessageType.stateSnapshot, forKey: .type)
            try container.encode(state, forKey: .state)
        case let .intentRejected(error):
            try container.encode(MessageType.intentRejected, forKey: .type)
            try container.encode(error, forKey: .error)
        case let .proximitySignal(signal):
            try container.encode(MessageType.proximitySignal, forKey: .type)
            try container.encode(signal, forKey: .signal)
        case let .lobbySnapshot(lobby):
            try container.encode(MessageType.lobbySnapshot, forKey: .type)
            try container.encode(lobby, forKey: .lobby)
        case let .joinLobby(player):
            try container.encode(MessageType.joinLobby, forKey: .type)
            try container.encode(player, forKey: .player)
        }
    }
}
