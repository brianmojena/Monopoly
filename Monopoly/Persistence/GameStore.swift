import Foundation

struct SavedGame: Codable, Equatable {
    let state: GameState
    let ownPlayerID: UUID
    let hostControlledPlayerIDs: Set<UUID>
    let savedAt: Date
}

/// Keeps the host's game in progress on disk so it survives the app being closed.
/// Only the host saves: it is the source of truth, and clients get the state back
/// from it when they reconnect.
final class GameStore {
    static let shared = GameStore(
        fileURL: URL.applicationSupportDirectory.appending(path: "saved-game.json")
    )

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func load() -> SavedGame? {
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        // A save from an older, incompatible version is treated as no save rather
        // than blocking the start screen.
        return try? decoder.decode(SavedGame.self, from: data)
    }

    func save(_ game: SavedGame) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(game).write(to: fileURL, options: .atomic)
    }

    func delete() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
