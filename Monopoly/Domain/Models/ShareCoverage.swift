import Foundation

/// Shares a shareholder gave up when another one paid their part of a level-up
/// (GAME_RULES section 4.3). The covered player can buy them back at any time for
/// exactly `amount`, while the payer still holds that many shares.
struct ShareCoverage: Identifiable, Codable, Equatable {
    let id: UUID
    let propertyID: UUID
    /// The shareholder who paid the covered part.
    let payerID: UUID
    /// The shareholder whose part was paid and who gave up the shares.
    let coveredPlayerID: UUID
    /// What was paid for them, and what buying them back costs.
    let amount: Int
    let shares: Int

    init(
        id: UUID = UUID(),
        propertyID: UUID,
        payerID: UUID,
        coveredPlayerID: UUID,
        amount: Int,
        shares: Int
    ) {
        self.id = id
        self.propertyID = propertyID
        self.payerID = payerID
        self.coveredPlayerID = coveredPlayerID
        self.amount = amount
        self.shares = shares
    }
}

/// What a level-up would charge each shareholder, worked out before it happens so the
/// screen can show it.
struct LevelUpPlan: Equatable {
    struct Coverage: Equatable {
        let playerID: UUID
        let amount: Int
        let shares: Int
    }

    let targetLevel: Int
    let cost: Int
    /// What each shareholder pays out of their own money; the player leveling up also
    /// pays everything in `coverages`.
    let payments: [(playerID: UUID, amount: Int)]
    /// Shareholders who can't pay their part, which the player leveling up covers.
    let coverages: [Coverage]

    static func == (lhs: LevelUpPlan, rhs: LevelUpPlan) -> Bool {
        lhs.targetLevel == rhs.targetLevel
            && lhs.cost == rhs.cost
            && lhs.coverages == rhs.coverages
            && lhs.payments.map(\.playerID) == rhs.payments.map(\.playerID)
            && lhs.payments.map(\.amount) == rhs.payments.map(\.amount)
    }
}
