import Foundation

struct AuctionBid: Codable, Equatable {
    let playerID: UUID
    let amount: Int

    init(playerID: UUID, amount: Int) {
        self.playerID = playerID
        self.amount = amount
    }
}
