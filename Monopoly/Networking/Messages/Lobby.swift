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
    var proximityPaymentsEnabled: Bool

    init(
        players: [LobbyPlayer] = [],
        creditCardsEnabled: Bool = true,
        proximityPaymentsEnabled: Bool = false
    ) {
        self.players = players
        self.creditCardsEnabled = creditCardsEnabled
        self.proximityPaymentsEnabled = proximityPaymentsEnabled
    }

    var canStart: Bool {
        Self.playerLimit.contains(players.count)
            && players.allSatisfy { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    func makeGameState(initialBalance: Int, properties: [Property]) -> GameState {
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
            activeHouseRules: creditCardsEnabled ? [.creditCards] : [],
            proximityPaymentsEnabled: proximityPaymentsEnabled
        )
    }
}
