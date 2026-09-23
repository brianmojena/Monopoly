import Foundation

struct Player: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var balance: Int
    var propertyIDs: [UUID]
    var status: PlayerStatus
    var creditCardLoans: [CreditCardLoan]

    var creditCardDebt: Int {
        creditCardLoans.reduce(0) { $0 + $1.remainingDebt }
    }

    init(
        id: UUID = UUID(),
        name: String,
        balance: Int,
        propertyIDs: [UUID] = [],
        status: PlayerStatus = .active,
        creditCardLoans: [CreditCardLoan] = []
    ) {
        self.id = id
        self.name = name
        self.balance = balance
        self.propertyIDs = propertyIDs
        self.status = status
        self.creditCardLoans = creditCardLoans
    }
}

enum PlayerStatus: String, Codable, Equatable {
    case active
    case bankrupt
}
