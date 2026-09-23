import Foundation

/// App-wide preferences, set once in Ajustes instead of in every game.
enum AppSettings {
    /// UserDefaults keys, also used by `@AppStorage` in the views.
    enum Key {
        static let playerName = "playerName"
        static let keepsScreenOn = "keepsScreenOn"
        static let activeGame = "activeGame"
    }

    static var playerName: String {
        get {
            (UserDefaults.standard.string(forKey: Key.playerName) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.playerName)
        }
    }

    /// On by default: a locked screen sends the app to the background, which drops
    /// the local-network connection to the other iPhones.
    static var keepsScreenOn: Bool {
        UserDefaults.standard.object(forKey: Key.keepsScreenOn) as? Bool ?? true
    }
}

/// The game this iPhone is in, remembered until the player leaves it on purpose so
/// the app goes straight back to it after being closed.
struct ActiveGameRecord: Codable, Equatable {
    enum Role: String, Codable {
        case host
        case client
    }

    let roomID: UUID
    let role: Role

    static func load(from defaults: UserDefaults = .standard) -> ActiveGameRecord? {
        defaults.data(forKey: AppSettings.Key.activeGame)
            .flatMap { try? JSONDecoder().decode(ActiveGameRecord.self, from: $0) }
    }

    static func save(_ record: ActiveGameRecord?, to defaults: UserDefaults = .standard) {
        guard let record else {
            defaults.removeObject(forKey: AppSettings.Key.activeGame)
            return
        }
        defaults.set(try? JSONEncoder().encode(record), forKey: AppSettings.Key.activeGame)
    }
}
