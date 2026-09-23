import Foundation

enum GameMode: String, Codable, CaseIterable, Equatable {
    case classic
    case monopolife
}

enum LifeRole: String, Codable, CaseIterable, Equatable, Hashable {
    case consumer
    case entrepreneur
    case saver
    case social
    case investor
    case globetrotter
}

enum LifePossession: String, Codable, CaseIterable, Equatable, Hashable {
    case car
    case television
    case foodTruck
}

/// Each like and dislike of a role (MONOPOLIFE_RULES section 3.3), used both to
/// apply it and to explain in the happiness log where the points came from.
enum LifeRoleEffect: String, Codable, CaseIterable, Equatable, Hashable {
    case consumerRentPaid
    case consumerLevelUp
    case consumerHoardedCash
    case entrepreneurOwnedProperties
    case entrepreneurRentReceived
    case entrepreneurMortgage
    case saverSavings
    case saverSalaryWithoutDebt
    case saverLoan
    case socialDeal
    case socialNoDeals
    case investorInvestmentCreated
    case investorPayout
    case investorDiversification
    case investorTax
    case globetrotterSalary
    case globetrotterStamp
    case globetrotterAllStamps
    case globetrotterPropertyBought
}

enum HappinessReason: Codable, Equatable, Hashable {
    case role(LifeRoleEffect)
    case lifeCard(String)
    case bankruptcy
}

struct HappinessEvent: Codable, Equatable {
    let playerID: UUID
    let delta: Int
    let reason: HappinessReason
    let round: Int
}

struct LifeProfile: Codable, Equatable {
    var role: LifeRole
    var happiness: Int
    var hasAcknowledgedRole: Bool
    /// Color groups the Globetrotter has paid rent in.
    var rentStamps: Set<ColorGroup>
    var scoredDealsThisRound: Int
    var tookPartInDealThisRound: Bool
    var possessions: Set<LifePossession>

    init(
        role: LifeRole,
        happiness: Int = 0,
        hasAcknowledgedRole: Bool = false,
        rentStamps: Set<ColorGroup> = [],
        scoredDealsThisRound: Int = 0,
        tookPartInDealThisRound: Bool = false,
        possessions: Set<LifePossession> = []
    ) {
        self.role = role
        self.happiness = happiness
        self.hasAcknowledgedRole = hasAcknowledgedRole
        self.rentStamps = rentStamps
        self.scoredDealsThisRound = scoredDealsThisRound
        self.tookPartInDealThisRound = tookPartInDealThisRound
        self.possessions = possessions
    }

    private enum CodingKeys: String, CodingKey {
        case role
        case happiness
        case hasAcknowledgedRole
        case rentStamps
        case scoredDealsThisRound
        case tookPartInDealThisRound
        case possessions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        role = try container.decode(LifeRole.self, forKey: .role)
        happiness = try container.decodeIfPresent(Int.self, forKey: .happiness) ?? 0
        hasAcknowledgedRole = try container.decodeIfPresent(Bool.self, forKey: .hasAcknowledgedRole) ?? false
        rentStamps = try container.decodeIfPresent(Set<ColorGroup>.self, forKey: .rentStamps) ?? []
        scoredDealsThisRound = try container.decodeIfPresent(Int.self, forKey: .scoredDealsThisRound) ?? 0
        tookPartInDealThisRound = try container.decodeIfPresent(Bool.self, forKey: .tookPartInDealThisRound) ?? false
        possessions = try container.decodeIfPresent(Set<LifePossession>.self, forKey: .possessions) ?? []
    }
}

/// A Life Card a player drew, kept so every device can show it. `sequence` grows
/// with every draw, so a device can tell a new draw from the one it already showed.
struct LifeCardDraw: Codable, Equatable {
    let playerID: UUID
    let cardID: String
    let sequence: Int
    /// Whether the card did anything; a possession card for something the player
    /// does not own is drawn but has no effect.
    let hadEffect: Bool
}

struct MonopolifeState: Codable, Equatable {
    static let roundLimitOptions = [10, 15, 20, 25]
    static let defaultRoundLimit = 15

    var roundLimit: Int
    var profiles: [UUID: LifeProfile]
    var happinessLog: [HappinessEvent]
    var isFinished: Bool
    /// Card IDs still to be drawn, in order.
    var lifeDeck: [String]
    /// A decision card waiting for its player to accept or pass.
    var pendingLifeCard: LifeCardDraw?
    var lastLifeCardDraw: LifeCardDraw?

    init(
        roundLimit: Int,
        profiles: [UUID: LifeProfile],
        happinessLog: [HappinessEvent] = [],
        isFinished: Bool = false,
        lifeDeck: [String] = [],
        pendingLifeCard: LifeCardDraw? = nil,
        lastLifeCardDraw: LifeCardDraw? = nil
    ) {
        self.roundLimit = roundLimit
        self.profiles = profiles
        self.happinessLog = happinessLog
        self.isFinished = isFinished
        self.lifeDeck = lifeDeck
        self.pendingLifeCard = pendingLifeCard
        self.lastLifeCardDraw = lastLifeCardDraw
    }

    private enum CodingKeys: String, CodingKey {
        case roundLimit
        case profiles
        case happinessLog
        case isFinished
        case lifeDeck
        case pendingLifeCard
        case lastLifeCardDraw
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        roundLimit = try container.decode(Int.self, forKey: .roundLimit)
        profiles = try container.decode([UUID: LifeProfile].self, forKey: .profiles)
        happinessLog = try container.decodeIfPresent([HappinessEvent].self, forKey: .happinessLog) ?? []
        isFinished = try container.decodeIfPresent(Bool.self, forKey: .isFinished) ?? false
        lifeDeck = try container.decodeIfPresent([String].self, forKey: .lifeDeck) ?? []
        pendingLifeCard = try container.decodeIfPresent(LifeCardDraw.self, forKey: .pendingLifeCard)
        lastLifeCardDraw = try container.decodeIfPresent(LifeCardDraw.self, forKey: .lastLifeCardDraw)
    }
}
