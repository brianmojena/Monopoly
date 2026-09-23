import Foundation

/// A game this iPhone joined as a client. The host keeps the game itself; this is
/// only what it takes to list the game in "Partidas recientes" and join it again
/// as the same player.
struct JoinedGame: Codable, Equatable, Identifiable {
    let roomID: UUID
    var hostName: String
    var playerID: UUID
    var playerNames: [String]
    /// Nil while the game is still in the waiting room.
    var round: Int?
    var mode: GameMode
    var lastPlayedAt: Date

    var id: UUID {
        roomID
    }
}

final class JoinedGamesStore {
    static let shared = JoinedGamesStore(defaults: .standard)

    static let limit = 10

    private let defaults: UserDefaults
    private let key = "joinedGames"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// Most recently played first.
    func loadAll() -> [JoinedGame] {
        guard let data = defaults.data(forKey: key),
              let games = try? decoder.decode([JoinedGame].self, from: data) else {
            return []
        }
        return games.sorted { $0.lastPlayedAt > $1.lastPlayedAt }
    }

    func load(roomID: UUID) -> JoinedGame? {
        loadAll().first { $0.roomID == roomID }
    }

    func save(_ game: JoinedGame) {
        var games = loadAll().filter { $0.roomID != game.roomID }
        games.insert(game, at: 0)
        write(Array(games.prefix(Self.limit)))
    }

    func delete(roomID: UUID) {
        write(loadAll().filter { $0.roomID != roomID })
    }

    private func write(_ games: [JoinedGame]) {
        defaults.set(try? encoder.encode(games), forKey: key)
    }
}
