import Foundation

struct TradeOffer: Codable, Equatable {
    let fromPlayerID: UUID
    let toPlayerID: UUID
    let offeredPropertyIDs: [UUID]
    let offeredMoney: Int
    let requestedPropertyIDs: [UUID]
    let requestedMoney: Int

    init(
        fromPlayerID: UUID,
        toPlayerID: UUID,
        offeredPropertyIDs: [UUID] = [],
        offeredMoney: Int = 0,
        requestedPropertyIDs: [UUID] = [],
        requestedMoney: Int = 0
    ) {
        self.fromPlayerID = fromPlayerID
        self.toPlayerID = toPlayerID
        self.offeredPropertyIDs = offeredPropertyIDs
        self.offeredMoney = offeredMoney
        self.requestedPropertyIDs = requestedPropertyIDs
        self.requestedMoney = requestedMoney
    }
}
