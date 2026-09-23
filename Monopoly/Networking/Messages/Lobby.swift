import Foundation

struct LobbyPlayer: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var isHostControlled: Bool

    init(id: UUID = UUID(), name: String, isHostControlled: Bool) {
        self.id = id
        self.name = name
        self.isHostControlled = isHostControlled
    }
}

struct Lobby: Codable, Equatable {
    static let playerLimit = 2...8

    var players: [LobbyPlayer]
    var creditCardsEnabled: Bool
    var freeParkingEnabled: Bool
    var proximityPaymentsEnabled: Bool
    var gameMode: GameMode
    /// Only used in Monopolife games.
    var roundLimit: Int
    /// Rounds between board events; nil turns them off.
    var boardEventInterval: Int?

    init(
        players: [LobbyPlayer] = [],
        creditCardsEnabled: Bool = true,
        freeParkingEnabled: Bool = false,
        proximityPaymentsEnabled: Bool = false,
        gameMode: GameMode = .classic,
        roundLimit: Int = MonopolifeState.defaultRoundLimit,
        boardEventInterval: Int? = nil
    ) {
        self.players = players
        self.creditCardsEnabled = creditCardsEnabled
        self.freeParkingEnabled = freeParkingEnabled
        self.proximityPaymentsEnabled = proximityPaymentsEnabled
        self.gameMode = gameMode
        self.roundLimit = roundLimit
        self.boardEventInterval = boardEventInterval
    }

    private enum CodingKeys: String, CodingKey {
        case players
        case creditCardsEnabled
        case freeParkingEnabled
        case proximityPaymentsEnabled
        case gameMode
        case roundLimit
        case boardEventInterval
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        players = try container.decode([LobbyPlayer].self, forKey: .players)
        creditCardsEnabled = try container.decode(Bool.self, forKey: .creditCardsEnabled)
        freeParkingEnabled = try container.decodeIfPresent(Bool.self, forKey: .freeParkingEnabled) ?? false
        proximityPaymentsEnabled = try container.decode(Bool.self, forKey: .proximityPaymentsEnabled)
        gameMode = try container.decodeIfPresent(GameMode.self, forKey: .gameMode) ?? .classic
        roundLimit = try container.decodeIfPresent(Int.self, forKey: .roundLimit) ?? MonopolifeState.defaultRoundLimit
        boardEventInterval = try container.decodeIfPresent(Int.self, forKey: .boardEventInterval)
    }

    var canStart: Bool {
        Self.playerLimit.contains(players.count)
            && players.allSatisfy { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var activeHouseRules: Set<HouseRule> {
        var rules: Set<HouseRule> = []
        if creditCardsEnabled {
            rules.insert(.creditCards)
        }
        if freeParkingEnabled {
            rules.insert(.freeParkingJackpot)
        }
        return rules
    }

    func makeGameState(initialBalance: Int, properties: [Property]) -> GameState {
        var generator = SystemRandomNumberGenerator()
        return makeGameState(initialBalance: initialBalance, properties: properties, using: &generator)
    }

    func makeGameState<Generator: RandomNumberGenerator>(
        initialBalance: Int,
        properties: [Property],
        using generator: inout Generator
    ) -> GameState {
        let gamePlayers = players.map { player in
            Player(
                id: player.id,
                name: player.name.trimmingCharacters(in: .whitespacesAndNewlines),
                balance: initialBalance
            )
        }
        return GameState(
            players: gamePlayers,
            properties: properties,
            currentPlayerID: gamePlayers.first?.id,
            activeHouseRules: activeHouseRules,
            proximityPaymentsEnabled: proximityPaymentsEnabled,
            mode: gameMode,
            monopolife: gameMode == .monopolife
                ? GameRules.makeMonopolifeState(
                    playerIDs: gamePlayers.map(\.id),
                    roundLimit: roundLimit,
                    using: &generator
                )
                : nil,
            boardEvents: boardEventInterval.map {
                BoardEventsState(interval: $0, randomState: generator.next())
            }
        )
    }
}
