import Foundation

/// A player's savings (GAME_RULES section 4.10): a variable account that takes and
/// gives money at any time, and fixed deposits locked until their last GO. Interest
/// is paid into the player's cash at every GO, never into the savings.
struct Savings: Codable, Equatable {
    var variableBalance: Int
    /// GOs the variable account has paid interest since it was last withdrawn from.
    var variableStreak: Int
    var fixedDeposits: [FixedDeposit]

    init(variableBalance: Int = 0, variableStreak: Int = 0, fixedDeposits: [FixedDeposit] = []) {
        self.variableBalance = variableBalance
        self.variableStreak = variableStreak
        self.fixedDeposits = fixedDeposits
    }

    var fixedTotal: Int {
        fixedDeposits.reduce(0) { $0 + $1.amount }
    }

    var total: Int {
        variableBalance + fixedTotal
    }

    var isEmpty: Bool {
        total == 0
    }
}

/// Money locked for a number of GOs chosen when it was deposited.
struct FixedDeposit: Identifiable, Codable, Equatable {
    static let termRange = 1...5

    let id: UUID
    let amount: Int
    /// GOs until the money comes back.
    let terms: Int
    var gosPaid: Int

    init(id: UUID = UUID(), amount: Int, terms: Int, gosPaid: Int = 0) {
        self.id = id
        self.amount = amount
        self.terms = terms
        self.gosPaid = gosPaid
    }

    var gosRemaining: Int {
        terms - gosPaid
    }
}
