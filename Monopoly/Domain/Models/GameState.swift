import Foundation

struct GameState: Codable, Equatable {
    var players: [Player]
    var properties: [Property]
    var currentPlayerID: UUID?
    var round: Int
    var activeHouseRules: Set<HouseRule>
    var marketDeals: [MarketDeal]
    var rentInvestments: [RentInvestment]
    /// Shares taken for paying another shareholder's part of a level-up, which that
    /// shareholder can buy back (GAME_RULES section 4.3).
    var shareCoverages: [ShareCoverage]
    var mode: GameMode
    /// Money waiting on Free Parking; only grows while `HouseRule.freeParkingJackpot` is active.
    var freeParkingPot: Int
    /// Present only in Monopolife games.
    var monopolife: MonopolifeState?
    /// Present only when the host turned board events on.
    var boardEvents: BoardEventsState?
    /// Rent changes left by host cards (GAME_RULES section 8.5).
    var hostCardRentEffects: [ActiveRentEffect]
    /// The last card the host played, so every device announces it.
    var lastHostCard: HostCardOccurrence?

    init(
        players: [Player],
        properties: [Property],
        currentPlayerID: UUID? = nil,
        round: Int = 1,
        activeHouseRules: Set<HouseRule> = [],
        marketDeals: [MarketDeal] = [],
        rentInvestments: [RentInvestment] = [],
        shareCoverages: [ShareCoverage] = [],
        mode: GameMode = .classic,
        freeParkingPot: Int = 0,
        monopolife: MonopolifeState? = nil,
        boardEvents: BoardEventsState? = nil,
        hostCardRentEffects: [ActiveRentEffect] = [],
        lastHostCard: HostCardOccurrence? = nil
    ) {
        self.players = players
        self.properties = properties
        self.currentPlayerID = currentPlayerID
        self.round = round
        self.activeHouseRules = activeHouseRules
        self.marketDeals = marketDeals
        self.rentInvestments = rentInvestments
        self.shareCoverages = shareCoverages
        self.mode = mode
        self.freeParkingPot = freeParkingPot
        self.monopolife = monopolife
        self.boardEvents = boardEvents
        self.hostCardRentEffects = hostCardRentEffects
        self.lastHostCard = lastHostCard
    }

    private enum CodingKeys: String, CodingKey {
        case players
        case properties
        case currentPlayerID
        case round
        case activeHouseRules
        case marketDeals
        case rentInvestments
        case shareCoverages
        case mode
        case freeParkingPot
        case monopolife
        case boardEvents
        case hostCardRentEffects
        case lastHostCard
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        players = try container.decode([Player].self, forKey: .players)
        properties = try container.decode([Property].self, forKey: .properties)
        currentPlayerID = try container.decodeIfPresent(UUID.self, forKey: .currentPlayerID)
        round = try container.decode(Int.self, forKey: .round)
        activeHouseRules = try container.decode(Set<HouseRule>.self, forKey: .activeHouseRules)
        marketDeals = try container.decode([MarketDeal].self, forKey: .marketDeals)
        rentInvestments = try container.decodeIfPresent([RentInvestment].self, forKey: .rentInvestments) ?? []
        shareCoverages = try container.decodeIfPresent([ShareCoverage].self, forKey: .shareCoverages) ?? []
        mode = try container.decodeIfPresent(GameMode.self, forKey: .mode) ?? .classic
        freeParkingPot = try container.decodeIfPresent(Int.self, forKey: .freeParkingPot) ?? 0
        monopolife = try container.decodeIfPresent(MonopolifeState.self, forKey: .monopolife)
        boardEvents = try container.decodeIfPresent(BoardEventsState.self, forKey: .boardEvents)
        hostCardRentEffects = try container.decodeIfPresent([ActiveRentEffect].self, forKey: .hostCardRentEffects) ?? []
        lastHostCard = try container.decodeIfPresent(HostCardOccurrence.self, forKey: .lastHostCard)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(players, forKey: .players)
        try container.encode(properties, forKey: .properties)
        try container.encodeIfPresent(currentPlayerID, forKey: .currentPlayerID)
        try container.encode(round, forKey: .round)
        try container.encode(activeHouseRules, forKey: .activeHouseRules)
        try container.encode(marketDeals, forKey: .marketDeals)
        try container.encode(rentInvestments, forKey: .rentInvestments)
        try container.encode(shareCoverages, forKey: .shareCoverages)
        try container.encode(mode, forKey: .mode)
        try container.encode(freeParkingPot, forKey: .freeParkingPot)
        try container.encodeIfPresent(monopolife, forKey: .monopolife)
        try container.encodeIfPresent(boardEvents, forKey: .boardEvents)
        try container.encode(hostCardRentEffects, forKey: .hostCardRentEffects)
        try container.encodeIfPresent(lastHostCard, forKey: .lastHostCard)
    }
}
