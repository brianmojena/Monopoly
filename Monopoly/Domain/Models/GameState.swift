import Foundation

struct GameState: Codable, Equatable {
    var players: [Player]
    var properties: [Property]
    var currentPlayerID: UUID?
    var round: Int
    var activeHouseRules: Set<HouseRule>
    var proximityPaymentsEnabled: Bool
    var marketDeals: [MarketDeal]

    init(
        players: [Player],
        properties: [Property],
        currentPlayerID: UUID? = nil,
        round: Int = 1,
        activeHouseRules: Set<HouseRule> = [],
        proximityPaymentsEnabled: Bool = false,
        marketDeals: [MarketDeal] = []
    ) {
        self.players = players
        self.properties = properties
        self.currentPlayerID = currentPlayerID
        self.round = round
        self.activeHouseRules = activeHouseRules
        self.proximityPaymentsEnabled = proximityPaymentsEnabled
        self.marketDeals = marketDeals
    }
}
