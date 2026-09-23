import Foundation

/// A game listed in "Partidas recientes": one this iPhone hosts (saved in full, see
/// `GameStore`) or one it joined (see `JoinedGamesStore`).
struct RecentGame: Identifiable {
    enum Kind {
        case hosted(SavedGame)
        case joined(JoinedGame)
    }

    let kind: Kind

    var id: UUID {
        switch kind {
        case let .hosted(game):
            return game.roomID
        case let .joined(game):
            return game.roomID
        }
    }

    var isHosted: Bool {
        if case .hosted = kind {
            return true
        }
        return false
    }

    var date: Date {
        switch kind {
        case let .hosted(game):
            return game.savedAt
        case let .joined(game):
            return game.lastPlayedAt
        }
    }

    var title: String {
        switch kind {
        case let .hosted(game):
            let modeName = game.state.mode == .monopolife ? "Monopolife" : "Monopoly Classic"
            return "Tu partida de \(modeName)"
        case let .joined(game):
            return game.hostName.isEmpty ? "Partida sin nombre" : "Partida de \(game.hostName)"
        }
    }

    var summary: String {
        let playerNames: [String]
        let progress: String
        switch kind {
        case let .hosted(game):
            playerNames = game.state.players.map(\.name)
            progress = game.state.monopolife?.isFinished == true ? "Terminada" : "Ronda \(game.state.round)"
        case let .joined(game):
            playerNames = game.playerNames
            progress = game.round.map { "Ronda \($0)" } ?? "En sala de espera"
        }
        let when = date.formatted(date: .abbreviated, time: .shortened)
        let players = playerNames.isEmpty ? "" : " · \(playerNames.joined(separator: ", "))"
        return "\(progress)\(players)\n\(when)"
    }

    /// Hosted and joined games together, most recently played first.
    static func load(
        gameStore: GameStore = .shared,
        joinedGamesStore: JoinedGamesStore = .shared
    ) -> [RecentGame] {
        let hosted = gameStore.loadAll().map { RecentGame(kind: .hosted($0)) }
        let joined = joinedGamesStore.loadAll().map { RecentGame(kind: .joined($0)) }
        return (hosted + joined).sorted { $0.date > $1.date }
    }
}
