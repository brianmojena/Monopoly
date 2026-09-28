import Foundation

/// A credit card loan paid in fixed installments, one per GO, whose interest rises with
/// every GO the loan stays open (GAME_RULES section 8.1).
struct CreditCardLoan: Identifiable, Codable, Equatable {
    let id: UUID
    /// The part of the borrowed amount not yet charged in any installment.
    var principalRemaining: Int
    var installmentsRemaining: Int
    /// The installment in progress (1 before the first GO), which sets the interest rate.
    var currentInstallment: Int
    /// What a GO charged and could not collect, interest included. It does not grow.
    var overdueDebt: Int
    /// The part of `overdueDebt` that is interest, which goes to the Free Parking pot as it is paid.
    var overdueInterest: Int

    init(
        id: UUID = UUID(),
        principal: Int,
        installmentsRemaining: Int = GameRules.creditCardInstallments,
        currentInstallment: Int = 1,
        overdueDebt: Int = 0,
        overdueInterest: Int = 0
    ) {
        self.id = id
        self.principalRemaining = principal
        self.installmentsRemaining = installmentsRemaining
        self.currentInstallment = currentInstallment
        self.overdueDebt = overdueDebt
        self.overdueInterest = overdueInterest
    }

    /// What it costs to pay the loan off right now.
    var remainingDebt: Int {
        overdueDebt + principalRemaining + GameRules.creditCardInterest(on: principalRemaining, installment: currentInstallment)
    }

    var isPaidOff: Bool {
        remainingDebt <= 0
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case principalRemaining
        case installmentsRemaining
        case currentInstallment
        case overdueDebt
        case overdueInterest
        // Loans saved before the escalating interest.
        case remainingDebt
        case remainingInterest
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        installmentsRemaining = try container.decode(Int.self, forKey: .installmentsRemaining)
        if let principal = try container.decodeIfPresent(Int.self, forKey: .principalRemaining) {
            principalRemaining = principal
            currentInstallment = try container.decode(Int.self, forKey: .currentInstallment)
            overdueDebt = try container.decode(Int.self, forKey: .overdueDebt)
            overdueInterest = try container.decode(Int.self, forKey: .overdueInterest)
        } else {
            let debt = try container.decode(Int.self, forKey: .remainingDebt)
            let interest = try container.decodeIfPresent(Int.self, forKey: .remainingInterest) ?? 0
            principalRemaining = max(0, debt - interest)
            installmentsRemaining = max(1, installmentsRemaining)
            currentInstallment = 1
            overdueDebt = 0
            overdueInterest = 0
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(principalRemaining, forKey: .principalRemaining)
        try container.encode(installmentsRemaining, forKey: .installmentsRemaining)
        try container.encode(currentInstallment, forKey: .currentInstallment)
        try container.encode(overdueDebt, forKey: .overdueDebt)
        try container.encode(overdueInterest, forKey: .overdueInterest)
    }
}
