import Foundation

/// Where a board event lands (GAME_RULES section 8.3), chosen at random when it happens.
enum BoardEventTarget: Codable, Equatable {
    /// 1 to 4, going around the board from GO.
    case side(Int)
    case colorGroup(ColorGroup)
    case property(UUID)
    case wholeBoard
    case allPlayers
}

/// A rent change a board event left on some properties.
struct ActiveRentEffect: Codable, Equatable, Identifiable {
    let id: UUID
    let eventID: String
    let propertyIDs: Set<UUID>
    let flat: Int
    let percent: Int
    /// The last round the effect applies to; nil for a permanent effect.
    let lastRound: Int?

    init(id: UUID = UUID(), eventID: String, propertyIDs: Set<UUID>, flat: Int, percent: Int, lastRound: Int?) {
        self.id = id
        self.eventID = eventID
        self.propertyIDs = propertyIDs
        self.flat = flat
        self.percent = percent
        self.lastRound = lastRound
    }
}

/// A board event that happened, kept so every device can announce it.
struct BoardEventOccurrence: Codable, Equatable, Identifiable {
    let sequence: Int
    let eventID: String
    /// The round that had just ended when the event happened.
    let round: Int
    let target: BoardEventTarget
    /// The properties the event touched (empty for events on players).
    let propertyIDs: [UUID]

    var id: Int { sequence }
}

struct BoardEventsState: Codable, Equatable {
    static let intervalOptions = [2, 3, 4, 5]

    /// An event happens at the end of every `interval` rounds.
    var interval: Int
    /// Seed of the event draws. Kept in the state so the rules stay deterministic and
    /// the host is the only one who draws.
    var randomState: UInt64
    var rentEffects: [ActiveRentEffect]
    var history: [BoardEventOccurrence]

    init(interval: Int, randomState: UInt64, rentEffects: [ActiveRentEffect] = [], history: [BoardEventOccurrence] = []) {
        self.interval = interval
        self.randomState = randomState
        self.rentEffects = rentEffects
        self.history = history
    }

    private enum CodingKeys: String, CodingKey {
        case interval
        case randomState
        case rentEffects
        case history
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        interval = try container.decode(Int.self, forKey: .interval)
        randomState = try container.decode(UInt64.self, forKey: .randomState)
        rentEffects = try container.decodeIfPresent([ActiveRentEffect].self, forKey: .rentEffects) ?? []
        history = try container.decodeIfPresent([BoardEventOccurrence].self, forKey: .history) ?? []
    }

    var lastOccurrence: BoardEventOccurrence? {
        history.last
    }
}

extension ColorGroup {
    /// The side of the board the group sits on, 1 to 4 going around from GO.
    var boardSide: Int {
        switch self {
        case .brown, .lightBlue:
            return 1
        case .pink, .orange:
            return 2
        case .red, .yellow:
            return 3
        case .green, .darkBlue:
            return 4
        }
    }
}

/// SplitMix64: small, fast and reproducible from a stored seed.
struct SeededRandom: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}
