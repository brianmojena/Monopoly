import Foundation

enum DebtCreditor: Codable, Equatable {
    case player(UUID)
    case bank
}

struct Debt: Codable, Equatable {
    let amount: Int
    let creditor: DebtCreditor

    init(amount: Int, creditor: DebtCreditor) {
        self.amount = amount
        self.creditor = creditor
    }
}
