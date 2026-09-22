import Foundation

enum GameIntent: Codable, Equatable {
    case buyProperty(playerID: UUID, propertyID: UUID)
    case resolveAuction(propertyID: UUID, bids: [AuctionBid])
    case collectRent(payerID: UUID, propertyID: UUID)
    case payTax(playerID: UUID, amount: Int)
    case collectSalary(playerID: UUID, amount: Int)
    case buildHouse(propertyID: UUID, playerID: UUID)
    case buildHotel(propertyID: UUID, playerID: UUID)
    case sellHouse(propertyID: UUID, playerID: UUID)
    case mortgageProperty(propertyID: UUID, playerID: UUID)
    case unmortgageProperty(propertyID: UUID, playerID: UUID)
    case declareBankruptcy(playerID: UUID, creditor: DebtCreditor)
    case executeTrade(offer: TradeOffer)
    case transferMoney(payerID: UUID, recipientID: UUID, amount: Int)
    case borrowOnCreditCard(playerID: UUID, amount: Int)
    case payCreditCard(playerID: UUID, amount: Int)

    private enum CodingKeys: String, CodingKey {
        case type
        case playerID
        case payerID
        case propertyID
        case amount
        case bids
        case creditor
        case offer
        case recipientID
    }

    private enum IntentType: String, Codable {
        case buyProperty
        case resolveAuction
        case collectRent
        case payTax
        case collectSalary
        case buildHouse
        case buildHotel
        case sellHouse
        case mortgageProperty
        case unmortgageProperty
        case declareBankruptcy
        case executeTrade
        case transferMoney
        case borrowOnCreditCard
        case payCreditCard
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(IntentType.self, forKey: .type)

        switch type {
        case .buyProperty:
            self = .buyProperty(
                playerID: try container.decode(UUID.self, forKey: .playerID),
                propertyID: try container.decode(UUID.self, forKey: .propertyID)
            )
        case .resolveAuction:
            self = .resolveAuction(
                propertyID: try container.decode(UUID.self, forKey: .propertyID),
                bids: try container.decode([AuctionBid].self, forKey: .bids)
            )
        case .collectRent:
            self = .collectRent(
                payerID: try container.decode(UUID.self, forKey: .payerID),
                propertyID: try container.decode(UUID.self, forKey: .propertyID)
            )
        case .payTax:
            self = .payTax(
                playerID: try container.decode(UUID.self, forKey: .playerID),
                amount: try container.decode(Int.self, forKey: .amount)
            )
        case .collectSalary:
            self = .collectSalary(
                playerID: try container.decode(UUID.self, forKey: .playerID),
                amount: try container.decode(Int.self, forKey: .amount)
            )
        case .buildHouse:
            self = .buildHouse(
                propertyID: try container.decode(UUID.self, forKey: .propertyID),
                playerID: try container.decode(UUID.self, forKey: .playerID)
            )
        case .buildHotel:
            self = .buildHotel(
                propertyID: try container.decode(UUID.self, forKey: .propertyID),
                playerID: try container.decode(UUID.self, forKey: .playerID)
            )
        case .sellHouse:
            self = .sellHouse(
                propertyID: try container.decode(UUID.self, forKey: .propertyID),
                playerID: try container.decode(UUID.self, forKey: .playerID)
            )
        case .mortgageProperty:
            self = .mortgageProperty(
                propertyID: try container.decode(UUID.self, forKey: .propertyID),
                playerID: try container.decode(UUID.self, forKey: .playerID)
            )
        case .unmortgageProperty:
            self = .unmortgageProperty(
                propertyID: try container.decode(UUID.self, forKey: .propertyID),
                playerID: try container.decode(UUID.self, forKey: .playerID)
            )
        case .declareBankruptcy:
            self = .declareBankruptcy(
                playerID: try container.decode(UUID.self, forKey: .playerID),
                creditor: try container.decode(DebtCreditor.self, forKey: .creditor)
            )
        case .executeTrade:
            self = .executeTrade(offer: try container.decode(TradeOffer.self, forKey: .offer))
        case .transferMoney:
            self = .transferMoney(
                payerID: try container.decode(UUID.self, forKey: .payerID),
                recipientID: try container.decode(UUID.self, forKey: .recipientID),
                amount: try container.decode(Int.self, forKey: .amount)
            )
        case .borrowOnCreditCard:
            self = .borrowOnCreditCard(
                playerID: try container.decode(UUID.self, forKey: .playerID),
                amount: try container.decode(Int.self, forKey: .amount)
            )
        case .payCreditCard:
            self = .payCreditCard(
                playerID: try container.decode(UUID.self, forKey: .playerID),
                amount: try container.decode(Int.self, forKey: .amount)
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .buyProperty(playerID, propertyID):
            try container.encode(IntentType.buyProperty, forKey: .type)
            try container.encode(playerID, forKey: .playerID)
            try container.encode(propertyID, forKey: .propertyID)
        case let .resolveAuction(propertyID, bids):
            try container.encode(IntentType.resolveAuction, forKey: .type)
            try container.encode(propertyID, forKey: .propertyID)
            try container.encode(bids, forKey: .bids)
        case let .collectRent(payerID, propertyID):
            try container.encode(IntentType.collectRent, forKey: .type)
            try container.encode(payerID, forKey: .payerID)
            try container.encode(propertyID, forKey: .propertyID)
        case let .payTax(playerID, amount):
            try container.encode(IntentType.payTax, forKey: .type)
            try container.encode(playerID, forKey: .playerID)
            try container.encode(amount, forKey: .amount)
        case let .collectSalary(playerID, amount):
            try container.encode(IntentType.collectSalary, forKey: .type)
            try container.encode(playerID, forKey: .playerID)
            try container.encode(amount, forKey: .amount)
        case let .buildHouse(propertyID, playerID):
            try container.encode(IntentType.buildHouse, forKey: .type)
            try container.encode(propertyID, forKey: .propertyID)
            try container.encode(playerID, forKey: .playerID)
        case let .buildHotel(propertyID, playerID):
            try container.encode(IntentType.buildHotel, forKey: .type)
            try container.encode(propertyID, forKey: .propertyID)
            try container.encode(playerID, forKey: .playerID)
        case let .sellHouse(propertyID, playerID):
            try container.encode(IntentType.sellHouse, forKey: .type)
            try container.encode(propertyID, forKey: .propertyID)
            try container.encode(playerID, forKey: .playerID)
        case let .mortgageProperty(propertyID, playerID):
            try container.encode(IntentType.mortgageProperty, forKey: .type)
            try container.encode(propertyID, forKey: .propertyID)
            try container.encode(playerID, forKey: .playerID)
        case let .unmortgageProperty(propertyID, playerID):
            try container.encode(IntentType.unmortgageProperty, forKey: .type)
            try container.encode(propertyID, forKey: .propertyID)
            try container.encode(playerID, forKey: .playerID)
        case let .declareBankruptcy(playerID, creditor):
            try container.encode(IntentType.declareBankruptcy, forKey: .type)
            try container.encode(playerID, forKey: .playerID)
            try container.encode(creditor, forKey: .creditor)
        case let .executeTrade(offer):
            try container.encode(IntentType.executeTrade, forKey: .type)
            try container.encode(offer, forKey: .offer)
        case let .transferMoney(payerID, recipientID, amount):
            try container.encode(IntentType.transferMoney, forKey: .type)
            try container.encode(payerID, forKey: .payerID)
            try container.encode(recipientID, forKey: .recipientID)
            try container.encode(amount, forKey: .amount)
        case let .borrowOnCreditCard(playerID, amount):
            try container.encode(IntentType.borrowOnCreditCard, forKey: .type)
            try container.encode(playerID, forKey: .playerID)
            try container.encode(amount, forKey: .amount)
        case let .payCreditCard(playerID, amount):
            try container.encode(IntentType.payCreditCard, forKey: .type)
            try container.encode(playerID, forKey: .playerID)
            try container.encode(amount, forKey: .amount)
        }
    }
}
