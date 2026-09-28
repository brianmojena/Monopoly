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
    case globetrotter
    case chameleon

    /// The roles dealt at the start of a game.
    static let playable = allCases

    /// The roles whose likes the Chameleon can take on.
    static let chameleonDisguises: [LifeRole] = [.consumer, .entrepreneur, .saver, .social, .globetrotter]

    /// Roles that no longer exist and what a saved game plays them as. The Rival became
    /// a rivalry every player has (MONOPOLIFE_RULES section 3.5).
    private static let removedRoles: [String: LifeRole] = [
        "investor": .entrepreneur,
        "rival": .social,
        "lender": .saver,
        "minimalist": .social
    ]

    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        guard let role = LifeRole(rawValue: rawValue) ?? Self.removedRoles[rawValue] else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Unknown life role \(rawValue)"
            ))
        }
        self = role
    }
}

enum LifePossession: String, Codable, CaseIterable, Equatable, Hashable {
    case car
    case television
    case foodTruck
}

/// Each like and dislike of a role (MONOPOLIFE_RULES section 3.3), used both to
/// apply it and to explain in the happiness log where the points came from.
enum LifeRoleEffect: String, Codable, CaseIterable, Equatable, Hashable {
    case consumerSpending
    case consumerHoardedCash
    case entrepreneurRentReceived
    case entrepreneurLevelUp
    case entrepreneurMortgage
    case saverSavings
    case saverSalaryWithoutDebt
    case saverLoan
    case socialInteraction
    case socialLonely
    case globetrotterSalary
    case globetrotterTrip
    case globetrotterStamp
    case globetrotterRevisit
    case globetrotterAllStamps
    case globetrotterPropertyBought
    case rivalAhead
    case rivalBehind
    case rivalRentFromTarget
    case rivalAuctionWon
    case rivalTargetSetback
    case rivalTargetBankrupt

    /// Effects of removed roles and likes, kept so saved happiness logs still load.
    private static let legacyEffects: [String: LifeRoleEffect] = [
        "investorInvestmentCreated": .entrepreneurLevelUp,
        "investorPayout": .entrepreneurRentReceived,
        "investorDiversification": .entrepreneurLevelUp,
        "investorTax": .entrepreneurMortgage,
        "consumerRentPaid": .consumerSpending,
        "consumerLevelUp": .consumerSpending,
        "entrepreneurOwnedProperties": .entrepreneurLevelUp,
        "entrepreneurStagnation": .entrepreneurMortgage,
        "socialDeal": .socialInteraction,
        "socialVisit": .socialInteraction,
        "socialNoDeals": .socialLonely,
        "lenderLoanGiven": .saverSavings,
        "lenderPaymentReceived": .saverSavings,
        "lenderLoanRepaid": .saverSavings,
        "lenderCollateralTaken": .saverSavings,
        "lenderLoanLost": .saverLoan,
        "minimalistGift": .socialInteraction,
        "minimalistSimpleLife": .socialInteraction,
        "minimalistPossession": .socialLonely
    ]

    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        guard let effect = LifeRoleEffect(rawValue: rawValue) ?? Self.legacyEffects[rawValue] else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Unknown life role effect \(rawValue)"
            ))
        }
        self = effect
    }
}

enum HappinessReason: Codable, Equatable, Hashable {
    case role(LifeRoleEffect)
    case lifeCard(String)
    case bankruptcy
    /// Paying rent somewhere, which every role enjoys (MONOPOLIFE_RULES section 3.4).
    case rentVisit
    /// The Chameleon took on a new role's likes.
    case newDisguise(LifeRole)
    /// Going to jail, the same for every role.
    case jail
    /// Starting another turn in jail.
    case jailTurn
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
    var possessions: Set<LifePossession>
    /// The role whose likes the Chameleon has right now.
    var disguise: LifeRole?
    /// The rival this player wants to beat (MONOPOLIFE_RULES section 3.5).
    var rivalTargetID: UUID?
    /// Money spent since the player's last turn ended, for the Consumer.
    var moneySpent: Int
    /// Money dealings with other players this round, for the Social.
    var interactionsThisRound: Int
    /// Points the Entrepreneur got from rent this round.
    var rentPointsThisRound: Int

    /// The role whose likes, dislikes and Life Card column apply: the Chameleon's
    /// current disguise, or the role itself.
    var activeRole: LifeRole {
        role == .chameleon ? disguise ?? .consumer : role
    }

    init(
        role: LifeRole,
        happiness: Int = 0,
        hasAcknowledgedRole: Bool = false,
        rentStamps: Set<ColorGroup> = [],
        possessions: Set<LifePossession> = [],
        disguise: LifeRole? = nil,
        rivalTargetID: UUID? = nil,
        moneySpent: Int = 0,
        interactionsThisRound: Int = 0,
        rentPointsThisRound: Int = 0
    ) {
        self.role = role
        self.happiness = happiness
        self.hasAcknowledgedRole = hasAcknowledgedRole
        self.rentStamps = rentStamps
        self.possessions = possessions
        self.disguise = disguise
        self.rivalTargetID = rivalTargetID
        self.moneySpent = moneySpent
        self.interactionsThisRound = interactionsThisRound
        self.rentPointsThisRound = rentPointsThisRound
    }

    private enum CodingKeys: String, CodingKey {
        case role
        case happiness
        case hasAcknowledgedRole
        case rentStamps
        case possessions
        case disguise
        case rivalTargetID
        case moneySpent
        case interactionsThisRound
        case rentPointsThisRound
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        role = try container.decode(LifeRole.self, forKey: .role)
        happiness = try container.decodeIfPresent(Int.self, forKey: .happiness) ?? 0
        hasAcknowledgedRole = try container.decodeIfPresent(Bool.self, forKey: .hasAcknowledgedRole) ?? false
        rentStamps = try container.decodeIfPresent(Set<ColorGroup>.self, forKey: .rentStamps) ?? []
        possessions = try container.decodeIfPresent(Set<LifePossession>.self, forKey: .possessions) ?? []
        disguise = try container.decodeIfPresent(LifeRole.self, forKey: .disguise)
        rivalTargetID = try container.decodeIfPresent(UUID.self, forKey: .rivalTargetID)
        moneySpent = try container.decodeIfPresent(Int.self, forKey: .moneySpent) ?? 0
        interactionsThisRound = try container.decodeIfPresent(Int.self, forKey: .interactionsThisRound) ?? 0
        rentPointsThisRound = try container.decodeIfPresent(Int.self, forKey: .rentPointsThisRound) ?? 0
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
    /// Monopolife starts with more money than Classic (MONOPOLIFE_RULES section 1).
    static let initialBalance = 2000
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
    /// Seed for draws made during the game, such as the Chameleon's next disguise.
    var randomState: UInt64
    /// A player who asked for a Life Card and is waiting for the host to deal it.
    var lifeCardRequest: UUID?

    init(
        roundLimit: Int,
        profiles: [UUID: LifeProfile],
        happinessLog: [HappinessEvent] = [],
        isFinished: Bool = false,
        lifeDeck: [String] = [],
        pendingLifeCard: LifeCardDraw? = nil,
        lastLifeCardDraw: LifeCardDraw? = nil,
        randomState: UInt64 = 0,
        lifeCardRequest: UUID? = nil
    ) {
        self.roundLimit = roundLimit
        self.profiles = profiles
        self.happinessLog = happinessLog
        self.isFinished = isFinished
        self.lifeDeck = lifeDeck
        self.pendingLifeCard = pendingLifeCard
        self.lastLifeCardDraw = lastLifeCardDraw
        self.randomState = randomState
        self.lifeCardRequest = lifeCardRequest
    }

    private enum CodingKeys: String, CodingKey {
        case roundLimit
        case profiles
        case happinessLog
        case isFinished
        case lifeDeck
        case pendingLifeCard
        case lastLifeCardDraw
        case randomState
        case lifeCardRequest
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
        randomState = try container.decodeIfPresent(UInt64.self, forKey: .randomState) ?? 0
        lifeCardRequest = try container.decodeIfPresent(UUID.self, forKey: .lifeCardRequest)
    }
}
