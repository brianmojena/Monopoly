import Foundation

struct Player: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var balance: Int
    var propertyIDs: [UUID]
    var status: PlayerStatus
    var creditCardLoans: [CreditCardLoan]
    var creditHistory: CreditHistory

    var creditCardDebt: Int {
        creditCardLoans.reduce(0) { $0 + $1.remainingDebt }
    }

    init(
        id: UUID = UUID(),
        name: String,
        balance: Int,
        propertyIDs: [UUID] = [],
        status: PlayerStatus = .active,
        creditCardLoans: [CreditCardLoan] = [],
        creditHistory: CreditHistory = CreditHistory()
    ) {
        self.id = id
        self.name = name
        self.balance = balance
        self.propertyIDs = propertyIDs
        self.status = status
        self.creditCardLoans = creditCardLoans
        self.creditHistory = creditHistory
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case balance
        case propertyIDs
        case status
        case creditCardLoans
        case creditHistory
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        balance = try container.decode(Int.self, forKey: .balance)
        propertyIDs = try container.decode([UUID].self, forKey: .propertyIDs)
        status = try container.decode(PlayerStatus.self, forKey: .status)
        creditCardLoans = try container.decode([CreditCardLoan].self, forKey: .creditCardLoans)
        creditHistory = try container.decodeIfPresent(CreditHistory.self, forKey: .creditHistory) ?? CreditHistory()
    }
}

/// How the bank trusts a player with credit (GAME_RULES section 8.1).
struct CreditHistory: Codable, Equatable {
    /// Loans the player finished paying.
    var paidOffLoans: Int
    /// GOs where an installment could not be covered in full.
    var missedPayments: Int

    init(paidOffLoans: Int = 0, missedPayments: Int = 0) {
        self.paidOffLoans = paidOffLoans
        self.missedPayments = missedPayments
    }
}

enum PlayerStatus: String, Codable, Equatable {
    case active
    case bankrupt
}
