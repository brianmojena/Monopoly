import Foundation

struct Player: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var balance: Int
    var propertyIDs: [UUID]
    var status: PlayerStatus
    var creditCardDebt: Int

    init(
        id: UUID = UUID(),
        name: String,
        balance: Int,
        propertyIDs: [UUID] = [],
        status: PlayerStatus = .active,
        creditCardDebt: Int = 0
    ) {
        self.id = id
        self.name = name
        self.balance = balance
        self.propertyIDs = propertyIDs
        self.status = status
        self.creditCardDebt = creditCardDebt
    }
}

enum PlayerStatus: String, Codable, Equatable {
    case active
    case bankrupt
}
