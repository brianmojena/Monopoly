import Foundation

struct GameState: Codable, Equatable {
    var players: [Player]
    var properties: [Property]
    var currentPlayerID: UUID?
    var round: Int
    var activeHouseRules: Set<HouseRule>
    var proximityPaymentsEnabled: Bool
    var marketDeals: [MarketDeal]
    var rentInvestments: [RentInvestment]
    var mode: GameMode
    /// Money waiting on Free Parking; only grows while `HouseRule.freeParkingJackpot` is active.
    var freeParkingPot: Int
    /// Present only in Monopolife games.
    var monopolife: MonopolifeState?

    init(
        players: [Player],
        properties: [Property],
        currentPlayerID: UUID? = nil,
        round: Int = 1,
        activeHouseRules: Set<HouseRule> = [],
        proximityPaymentsEnabled: Bool = false,
        marketDeals: [MarketDeal] = [],
        rentInvestments: [RentInvestment] = [],
        mode: GameMode = .classic,
        freeParkingPot: Int = 0,
        monopolife: MonopolifeState? = nil
    ) {
        self.players = players
        self.properties = properties
        self.currentPlayerID = currentPlayerID
        self.round = round
        self.activeHouseRules = activeHouseRules
        self.proximityPaymentsEnabled = proximityPaymentsEnabled
        self.marketDeals = marketDeals
        self.rentInvestments = rentInvestments
        self.mode = mode
        self.freeParkingPot = freeParkingPot
        self.monopolife = monopolife
    }

    private enum CodingKeys: String, CodingKey {
        case players
        case properties
        case currentPlayerID
        case round
        case activeHouseRules
        case proximityPaymentsEnabled
        case marketDeals
        case rentInvestments
        case mode
        case freeParkingPot
        case monopolife
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        players = try container.decode([Player].self, forKey: .players)
        properties = try container.decode([Property].self, forKey: .properties)
        currentPlayerID = try container.decodeIfPresent(UUID.self, forKey: .currentPlayerID)
        round = try container.decode(Int.self, forKey: .round)
        activeHouseRules = try container.decode(Set<HouseRule>.self, forKey: .activeHouseRules)
        proximityPaymentsEnabled = try container.decode(Bool.self, forKey: .proximityPaymentsEnabled)
        marketDeals = try container.decode([MarketDeal].self, forKey: .marketDeals)
        rentInvestments = try container.decodeIfPresent([RentInvestment].self, forKey: .rentInvestments) ?? []
        mode = try container.decodeIfPresent(GameMode.self, forKey: .mode) ?? .classic
        freeParkingPot = try container.decodeIfPresent(Int.self, forKey: .freeParkingPot) ?? 0
        monopolife = try container.decodeIfPresent(MonopolifeState.self, forKey: .monopolife)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(players, forKey: .players)
        try container.encode(properties, forKey: .properties)
        try container.encodeIfPresent(currentPlayerID, forKey: .currentPlayerID)
        try container.encode(round, forKey: .round)
        try container.encode(activeHouseRules, forKey: .activeHouseRules)
        try container.encode(proximityPaymentsEnabled, forKey: .proximityPaymentsEnabled)
        try container.encode(marketDeals, forKey: .marketDeals)
        try container.encode(rentInvestments, forKey: .rentInvestments)
        try container.encode(mode, forKey: .mode)
        try container.encode(freeParkingPot, forKey: .freeParkingPot)
        try container.encodeIfPresent(monopolife, forKey: .monopolife)
    }
}
