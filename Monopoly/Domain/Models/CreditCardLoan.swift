import Foundation

struct CreditCardLoan: Identifiable, Codable, Equatable {
    let id: UUID
    var remainingDebt: Int
    var installmentsRemaining: Int
    var postponementsRemaining: Int
    /// The part of `remainingDebt` that is interest, which goes to the Free Parking pot as it is paid.
    var remainingInterest: Int

    init(
        id: UUID = UUID(),
        remainingDebt: Int,
        installmentsRemaining: Int,
        postponementsRemaining: Int,
        remainingInterest: Int = 0
    ) {
        self.id = id
        self.remainingDebt = remainingDebt
        self.installmentsRemaining = installmentsRemaining
        self.postponementsRemaining = postponementsRemaining
        self.remainingInterest = remainingInterest
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case remainingDebt
        case installmentsRemaining
        case postponementsRemaining
        case remainingInterest
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        remainingDebt = try container.decode(Int.self, forKey: .remainingDebt)
        installmentsRemaining = try container.decode(Int.self, forKey: .installmentsRemaining)
        postponementsRemaining = try container.decode(Int.self, forKey: .postponementsRemaining)
        remainingInterest = try container.decodeIfPresent(Int.self, forKey: .remainingInterest) ?? 0
    }
}
