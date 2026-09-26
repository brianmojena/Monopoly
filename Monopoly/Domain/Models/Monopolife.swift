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
    case lender
    case minimalist

    /// Coming soon: its rules are in place, but it isn't dealt yet (MONOPOLIFE_RULES 3.3).
    var isComingSoon: Bool {
        self == .minimalist
    }

    /// The roles dealt at the start of a game.
    static let playable = allCases.filter { !$0.isComingSoon }

    /// The roles whose likes the Chameleon can take on.
    static let chameleonDisguises: [LifeRole] = [.consumer, .entrepreneur, .saver, .social, .globetrotter, .lender]

    /// Roles that no longer exist and what a saved game plays them as. The Rival became
    /// a rivalry every player has (MONOPOLIFE_RULES section 3.5).
    private static let removedRoles: [String: LifeRole] = [
        "investor": .entrepreneur,
        "rival": .social
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
    case consumerRentPaid
    case consumerLevelUp
    case consumerHoardedCash
    case entrepreneurOwnedProperties
    case entrepreneurRentReceived
    case entrepreneurMortgage
    case entrepreneurStagnation
    case saverSavings
    case saverSalaryWithoutDebt
    case saverLoan
    case socialDeal
    case socialVisit
    case socialNoDeals
    case globetrotterSalary
    case globetrotterTrip
    case globetrotterStamp
    case globetrotterRevisit
    case globetrotterAllStamps
    case globetrotterPropertyBought
    case lenderLoanGiven
    case lenderPaymentReceived
    case lenderLoanRepaid
    case lenderCollateralTaken
    case lenderLoanLost
    case rivalAhead
    case rivalBehind
    case rivalRentFromTarget
    case rivalAuctionWon
    case rivalTargetSetback
    case rivalTargetBankrupt
    case minimalistGift
    case minimalistSimpleLife
    case minimalistPossession

    /// Effects of the removed Investor role, kept so saved happiness logs still load.
    private static let legacyInvestorEffects: [String: LifeRoleEffect] = [
        "investorInvestmentCreated": .entrepreneurOwnedProperties,
        "investorPayout": .entrepreneurRentReceived,
        "investorDiversification": .entrepreneurOwnedProperties,
        "investorTax": .entrepreneurMortgage
    ]

    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        guard let effect = LifeRoleEffect(rawValue: rawValue) ?? Self.legacyInvestorEffects[rawValue] else {
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
    var scoredDealsThisRound: Int
    var tookPartInDealThisRound: Bool
    var possessions: Set<LifePossession>
    /// Rents received this round that counted for the Entrepreneur.
    var scoredRentsThisRound: Int
    var leveledUpThisRound: Bool
    /// Rounds in a row the Entrepreneur ended without leveling anything up.
    var roundsWithoutLevelUp: Int
    /// Players the Social paid rent to or collected rent from this round.
    var rentContactsThisRound: Set<UUID>
    /// The role whose likes the Chameleon has right now.
    var disguise: LifeRole?
    /// The rival this player wants to beat (MONOPOLIFE_RULES section 3.5).
    var rivalTargetID: UUID?
    var scoredLoansThisRound: Int
    var scoredLoanPaymentsThisRound: Int
    /// Money the Minimalist gave away to other players this round.
    var moneyGivenThisRound: Int

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
        scoredDealsThisRound: Int = 0,
        tookPartInDealThisRound: Bool = false,
        possessions: Set<LifePossession> = [],
        scoredRentsThisRound: Int = 0,
        leveledUpThisRound: Bool = false,
        roundsWithoutLevelUp: Int = 0,
        rentContactsThisRound: Set<UUID> = [],
        disguise: LifeRole? = nil,
        rivalTargetID: UUID? = nil,
        scoredLoansThisRound: Int = 0,
        scoredLoanPaymentsThisRound: Int = 0,
        moneyGivenThisRound: Int = 0
    ) {
        self.role = role
        self.happiness = happiness
        self.hasAcknowledgedRole = hasAcknowledgedRole
        self.rentStamps = rentStamps
        self.scoredDealsThisRound = scoredDealsThisRound
        self.tookPartInDealThisRound = tookPartInDealThisRound
        self.possessions = possessions
        self.scoredRentsThisRound = scoredRentsThisRound
        self.leveledUpThisRound = leveledUpThisRound
        self.roundsWithoutLevelUp = roundsWithoutLevelUp
        self.rentContactsThisRound = rentContactsThisRound
        self.disguise = disguise
        self.rivalTargetID = rivalTargetID
        self.scoredLoansThisRound = scoredLoansThisRound
        self.scoredLoanPaymentsThisRound = scoredLoanPaymentsThisRound
        self.moneyGivenThisRound = moneyGivenThisRound
    }

    private enum CodingKeys: String, CodingKey {
        case role
        case happiness
        case hasAcknowledgedRole
        case rentStamps
        case scoredDealsThisRound
        case tookPartInDealThisRound
        case possessions
        case scoredRentsThisRound
        case leveledUpThisRound
        case roundsWithoutLevelUp
        case rentContactsThisRound
        case disguise
        case rivalTargetID
        case scoredLoansThisRound
        case scoredLoanPaymentsThisRound
        case moneyGivenThisRound
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
        scoredRentsThisRound = try container.decodeIfPresent(Int.self, forKey: .scoredRentsThisRound) ?? 0
        leveledUpThisRound = try container.decodeIfPresent(Bool.self, forKey: .leveledUpThisRound) ?? false
        roundsWithoutLevelUp = try container.decodeIfPresent(Int.self, forKey: .roundsWithoutLevelUp) ?? 0
        rentContactsThisRound = try container.decodeIfPresent(Set<UUID>.self, forKey: .rentContactsThisRound) ?? []
        disguise = try container.decodeIfPresent(LifeRole.self, forKey: .disguise)
        rivalTargetID = try container.decodeIfPresent(UUID.self, forKey: .rivalTargetID)
        scoredLoansThisRound = try container.decodeIfPresent(Int.self, forKey: .scoredLoansThisRound) ?? 0
        scoredLoanPaymentsThisRound = try container.decodeIfPresent(Int.self, forKey: .scoredLoanPaymentsThisRound) ?? 0
        moneyGivenThisRound = try container.decodeIfPresent(Int.self, forKey: .moneyGivenThisRound) ?? 0
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
