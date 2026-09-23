import Foundation

struct CreditCardLoan: Identifiable, Codable, Equatable {
    let id: UUID
    var remainingDebt: Int
    var installmentsRemaining: Int
    var postponementsRemaining: Int

    init(
        id: UUID = UUID(),
        remainingDebt: Int,
        installmentsRemaining: Int,
        postponementsRemaining: Int
    ) {
        self.id = id
        self.remainingDebt = remainingDebt
        self.installmentsRemaining = installmentsRemaining
        self.postponementsRemaining = postponementsRemaining
    }
}
