import Foundation

struct SavedGame: Codable, Equatable {
    let roomID: UUID
    let state: GameState
    let ownPlayerID: UUID
    let hostControlledPlayerIDs: Set<UUID>
    let savedAt: Date
}

/// Keeps every game this iPhone hosts on disk, one file per room, so they survive
/// the app being closed and show up in "Partidas recientes". Only the host saves:
/// it is the source of truth, and clients get the state back from it when they
/// reconnect.
final class GameStore {
    static let shared = GameStore(
        directoryURL: URL.applicationSupportDirectory.appending(path: "saved-games"),
        legacyFileURL: URL.applicationSupportDirectory.appending(path: "saved-game.json")
    )

    private let directoryURL: URL
    private let legacyFileURL: URL?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// - Parameter legacyFileURL: the single save older versions kept; it is moved
    ///   into `directoryURL` the first time the store is read.
    init(directoryURL: URL, legacyFileURL: URL? = nil) {
        self.directoryURL = directoryURL
        self.legacyFileURL = legacyFileURL
    }

    func load(roomID: UUID) -> SavedGame? {
        migrateLegacySave()
        return decode(at: fileURL(for: roomID))
    }

    /// Every saved game, most recently played first.
    func loadAll() -> [SavedGame] {
        migrateLegacySave()
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        )) ?? []
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap(decode(at:))
            .sorted { $0.savedAt > $1.savedAt }
    }

    func save(_ game: SavedGame) throws {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try encoder.encode(game).write(to: fileURL(for: game.roomID), options: .atomic)
    }

    func delete(roomID: UUID) {
        try? FileManager.default.removeItem(at: fileURL(for: roomID))
    }

    private func fileURL(for roomID: UUID) -> URL {
        directoryURL.appending(path: "\(roomID.uuidString).json")
    }

    // A save from an older, incompatible version is treated as no save rather than
    // blocking the start screen.
    private func decode(at url: URL) -> SavedGame? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? decoder.decode(SavedGame.self, from: data)
    }

    private func migrateLegacySave() {
        guard let legacyFileURL, FileManager.default.fileExists(atPath: legacyFileURL.path(percentEncoded: false)) else {
            return
        }
        if let game = decode(at: legacyFileURL), decode(at: fileURL(for: game.roomID)) == nil {
            try? save(game)
        }
        try? FileManager.default.removeItem(at: legacyFileURL)
    }
}
