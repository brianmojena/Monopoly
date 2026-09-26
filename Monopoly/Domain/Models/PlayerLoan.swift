import Foundation

/// Shares of one of the borrower's properties that go to the lender if the loan
/// comes due unpaid (GAME_RULES section 4.9).
struct LoanCollateral: Codable, Equatable {
    let propertyID: UUID
    var shares: Int
}

/// Money one player lends another on the terms they agreed (GAME_RULES section 4.9).
/// It is proposed inside a Market deal and becomes active when the deal settles.
struct PlayerLoan: Identifiable, Codable, Equatable {
    static let interestRange = 0...100
    static let rentPercentageRange = 5...100

    let id: UUID
    let lenderID: UUID
    let borrowerID: UUID
    let principal: Int
    let interestPercentage: Int
    /// What the borrower still owes, interest included.
    var remainingDebt: Int
    /// Paid automatically every time the borrower collects the GO salary.
    let goPayment: Int?
    /// Share of the rent the borrower collects that goes to the lender.
    let rentPercentage: Int?
    /// The round at whose end whatever is left comes due.
    let dueRound: Int?
    var collateral: LoanCollateral?
    /// Came due without being paid and had no collateral: every GO takes all it can.
    var isOverdue: Bool

    init(
        id: UUID = UUID(),
        lenderID: UUID,
        borrowerID: UUID,
        principal: Int,
        interestPercentage: Int = 0,
        goPayment: Int? = nil,
        rentPercentage: Int? = nil,
        dueRound: Int? = nil,
        collateral: LoanCollateral? = nil,
        isOverdue: Bool = false
    ) {
        self.id = id
        self.lenderID = lenderID
        self.borrowerID = borrowerID
        self.principal = principal
        self.interestPercentage = interestPercentage
        self.remainingDebt = Self.totalDebt(principal: principal, interestPercentage: interestPercentage)
        self.goPayment = goPayment
        self.rentPercentage = rentPercentage
        self.dueRound = dueRound
        self.collateral = collateral
        self.isOverdue = isOverdue
    }

    /// The principal plus its interest, rounded up.
    static func totalDebt(principal: Int, interestPercentage: Int) -> Int {
        principal + (principal * interestPercentage + 99) / 100
    }

    var totalDebt: Int {
        Self.totalDebt(principal: principal, interestPercentage: interestPercentage)
    }

    /// What the next GO takes, before checking the borrower's cash.
    var goPaymentDue: Int {
        if isOverdue {
            return remainingDebt
        }
        return min(goPayment ?? 0, remainingDebt)
    }
}
