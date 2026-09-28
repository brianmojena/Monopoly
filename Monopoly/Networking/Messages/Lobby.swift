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
    static let startingBalanceRange = 500...10_000
    static let startingBalanceStep = 100
    static let startingBalanceSpreadOptions = [0, 100, 200]

    var players: [LobbyPlayer]
    var creditCardsEnabled: Bool
    var freeParkingEnabled: Bool
    /// Only used in Classic games.
    var hiddenLevelsEnabled: Bool
    /// Savings accounts (GAME_RULES section 4.10), in both modes.
    var savingsEnabled: Bool
    var gameMode: GameMode
    /// Only used in Monopolife games.
    var roundLimit: Int
    /// Rounds between board events (the fewest, for a random gap); nil turns them off.
    var boardEventInterval: Int?
    /// Most rounds between board events when the gap is random; nil for a fixed gap.
    var boardEventMaxInterval: Int?
    /// Only used in Classic games (GAME_RULES section 7).
    var endConditions: ClassicEndConditions
    /// What the poorest player starts with; nil uses the mode's default (GAME_RULES section 8.6).
    var startingBalance: Int?
    /// With a spread, players start this much apart from each other, in random order.
    var startingBalanceSpread: Int

    init(
        players: [LobbyPlayer] = [],
        creditCardsEnabled: Bool = true,
        freeParkingEnabled: Bool = false,
        hiddenLevelsEnabled: Bool = false,
        savingsEnabled: Bool = false,
        gameMode: GameMode = .classic,
        roundLimit: Int = MonopolifeState.defaultRoundLimit,
        boardEventInterval: Int? = nil,
        boardEventMaxInterval: Int? = nil,
        endConditions: ClassicEndConditions = ClassicEndConditions(),
        startingBalance: Int? = nil,
        startingBalanceSpread: Int = 0
    ) {
        self.players = players
        self.creditCardsEnabled = creditCardsEnabled
        self.freeParkingEnabled = freeParkingEnabled
        self.hiddenLevelsEnabled = hiddenLevelsEnabled
        self.savingsEnabled = savingsEnabled
        self.gameMode = gameMode
        self.roundLimit = roundLimit
        self.boardEventInterval = boardEventInterval
        self.boardEventMaxInterval = boardEventMaxInterval
        self.endConditions = endConditions
        self.startingBalance = startingBalance
        self.startingBalanceSpread = startingBalanceSpread
    }

    private enum CodingKeys: String, CodingKey {
        case players
        case creditCardsEnabled
        case freeParkingEnabled
        case hiddenLevelsEnabled
        case savingsEnabled
        case gameMode
        case roundLimit
        case boardEventInterval
        case boardEventMaxInterval
        case endConditions
        case startingBalance
        case startingBalanceSpread
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        players = try container.decode([LobbyPlayer].self, forKey: .players)
        creditCardsEnabled = try container.decode(Bool.self, forKey: .creditCardsEnabled)
        freeParkingEnabled = try container.decodeIfPresent(Bool.self, forKey: .freeParkingEnabled) ?? false
        hiddenLevelsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hiddenLevelsEnabled) ?? false
        savingsEnabled = try container.decodeIfPresent(Bool.self, forKey: .savingsEnabled) ?? false
        gameMode = try container.decodeIfPresent(GameMode.self, forKey: .gameMode) ?? .classic
        roundLimit = try container.decodeIfPresent(Int.self, forKey: .roundLimit) ?? MonopolifeState.defaultRoundLimit
        boardEventInterval = try container.decodeIfPresent(Int.self, forKey: .boardEventInterval)
        boardEventMaxInterval = try container.decodeIfPresent(Int.self, forKey: .boardEventMaxInterval)
        endConditions = try container.decodeIfPresent(ClassicEndConditions.self, forKey: .endConditions) ?? ClassicEndConditions()
        startingBalance = try container.decodeIfPresent(Int.self, forKey: .startingBalance)
        startingBalanceSpread = try container.decodeIfPresent(Int.self, forKey: .startingBalanceSpread) ?? 0
    }

    /// The balance the poorest player starts with, given the Classic default.
    func baseStartingBalance(classicDefault: Int) -> Int {
        startingBalance ?? (gameMode == .monopolife ? MonopolifeState.initialBalance : classicDefault)
    }

    /// Every starting balance, from the poorest to the richest player.
    func startingBalances(classicDefault: Int) -> [Int] {
        let base = baseStartingBalance(classicDefault: classicDefault)
        return players.indices.map { base + $0 * startingBalanceSpread }
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
        if hiddenLevelsEnabled, gameMode == .classic {
            rules.insert(.hiddenPropertyLevels)
        }
        if savingsEnabled {
            rules.insert(.savingsAccounts)
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
                balance: baseStartingBalance(classicDefault: initialBalance)
            )
        }
        var state = GameState(
            players: gamePlayers,
            properties: properties,
            currentPlayerID: gamePlayers.first?.id,
            activeHouseRules: activeHouseRules,
            mode: gameMode,
            monopolife: gameMode == .monopolife
                ? GameRules.makeMonopolifeState(
                    playerIDs: gamePlayers.map(\.id),
                    roundLimit: roundLimit,
                    using: &generator
                )
                : nil,
            boardEvents: boardEventInterval.map {
                BoardEventsState(interval: $0, maxInterval: boardEventMaxInterval, randomState: generator.next())
            },
            endConditions: gameMode == .classic ? startingEndConditions(playerCount: gamePlayers.count) : ClassicEndConditions()
        )
        // Drawn last, so a game without a spread keeps the same random roles and events.
        if startingBalanceSpread > 0 {
            let steps = Array(state.players.indices).shuffled(using: &generator)
            for (index, step) in zip(state.players.indices, steps) {
                state.players[index].balance += step * startingBalanceSpread
            }
        }
        return state
    }

    /// A bankruptcy count that would need everyone to go broke means "until one is left".
    private func startingEndConditions(playerCount: Int) -> ClassicEndConditions {
        var conditions = endConditions
        if let count = conditions.bankruptciesToEnd, count >= playerCount - 1 {
            conditions.bankruptciesToEnd = nil
        }
        return conditions
    }
}
