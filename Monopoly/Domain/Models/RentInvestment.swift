import Foundation

struct RentInvestment: Identifiable, Codable, Equatable {
    let id: UUID
    let investorID: UUID
    let recipientID: UUID
    let propertyID: UUID
    let percentage: Int

    init(
        id: UUID = UUID(),
        investorID: UUID,
        recipientID: UUID,
        propertyID: UUID,
        percentage: Int
    ) {
        self.id = id
        self.investorID = investorID
        self.recipientID = recipientID
        self.propertyID = propertyID
        self.percentage = percentage
    }
}
