import Foundation

struct GameState: Codable, Equatable {
    var players: [Player]
    var properties: [Property]
    var currentPlayerID: UUID?
    var activeHouseRules: Set<HouseRule>

    init(
        players: [Player],
        properties: [Property],
        currentPlayerID: UUID? = nil,
        activeHouseRules: Set<HouseRule> = []
    ) {
        self.players = players
        self.properties = properties
        self.currentPlayerID = currentPlayerID
        self.activeHouseRules = activeHouseRules
    }
}
