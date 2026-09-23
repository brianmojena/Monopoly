import Foundation

enum GameIntent: Codable, Equatable {
    case buyProperty(playerID: UUID, propertyID: UUID)
    case resolveAuction(propertyID: UUID, bids: [AuctionBid])
    case collectRent(payerID: UUID, propertyID: UUID)
    case payTax(playerID: UUID, amount: Int)
    case payTravel(playerID: UUID, route: TravelRoute)
    case collectFreeParking(playerID: UUID)
    case collectSalary(playerID: UUID, amount: Int, postponedLoanIDs: Set<UUID> = [])
    case levelUp(propertyID: UUID, playerID: UUID)
    case levelDown(propertyID: UUID, playerID: UUID)
    case mortgageProperty(propertyID: UUID, playerID: UUID)
    case unmortgageProperty(propertyID: UUID, playerID: UUID)
    case declareBankruptcy(playerID: UUID, creditor: DebtCreditor)
    case proposeDeal(MarketDeal)
    case acceptDeal(dealID: UUID)
    case rejectDeal(dealID: UUID)
    case transferMoney(payerID: UUID, recipientID: UUID, amount: Int)
    case borrowOnCreditCard(playerID: UUID, amount: Int, installments: Int)
    case payCreditCard(playerID: UUID, loanID: UUID, amount: Int)
    case endTurn(playerID: UUID)
    case skipTurn
    case acknowledgeRole(playerID: UUID)
    case drawLifeCard(playerID: UUID)
    case resolveLifeCardDecision(playerID: UUID, accept: Bool)

    private enum CodingKeys: String, CodingKey {
        case type
        case playerID
        case payerID
        case propertyID
        case amount
        case bids
        case creditor
        case deal
        case dealID
        case recipientID
        case postponedLoanIDs
        case installments
        case loanID
        case accept
        case route
    }

    private enum IntentType: String, Codable {
        case buyProperty
        case resolveAuction
        case collectRent
        case payTax
        case payTravel
        case collectFreeParking
        case collectSalary
        case levelUp
        case levelDown
        case mortgageProperty
        case unmortgageProperty
        case declareBankruptcy
        case proposeDeal
        case acceptDeal
        case rejectDeal
        case transferMoney
        case borrowOnCreditCard
        case payCreditCard
        case endTurn
        case skipTurn
        case acknowledgeRole
        case drawLifeCard
        case resolveLifeCardDecision
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
        case .payTravel:
            self = .payTravel(
                playerID: try container.decode(UUID.self, forKey: .playerID),
                route: try container.decode(TravelRoute.self, forKey: .route)
            )
        case .collectFreeParking:
            self = .collectFreeParking(playerID: try container.decode(UUID.self, forKey: .playerID))
        case .collectSalary:
            self = .collectSalary(
                playerID: try container.decode(UUID.self, forKey: .playerID),
                amount: try container.decode(Int.self, forKey: .amount),
                postponedLoanIDs: try container.decode(Set<UUID>.self, forKey: .postponedLoanIDs)
            )
        case .levelUp:
            self = .levelUp(
                propertyID: try container.decode(UUID.self, forKey: .propertyID),
                playerID: try container.decode(UUID.self, forKey: .playerID)
            )
        case .levelDown:
            self = .levelDown(
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
        case .proposeDeal:
            self = .proposeDeal(try container.decode(MarketDeal.self, forKey: .deal))
        case .acceptDeal:
            self = .acceptDeal(dealID: try container.decode(UUID.self, forKey: .dealID))
        case .rejectDeal:
            self = .rejectDeal(dealID: try container.decode(UUID.self, forKey: .dealID))
        case .transferMoney:
            self = .transferMoney(
                payerID: try container.decode(UUID.self, forKey: .payerID),
                recipientID: try container.decode(UUID.self, forKey: .recipientID),
                amount: try container.decode(Int.self, forKey: .amount)
            )
        case .borrowOnCreditCard:
            self = .borrowOnCreditCard(
                playerID: try container.decode(UUID.self, forKey: .playerID),
                amount: try container.decode(Int.self, forKey: .amount),
                installments: try container.decode(Int.self, forKey: .installments)
            )
        case .payCreditCard:
            self = .payCreditCard(
                playerID: try container.decode(UUID.self, forKey: .playerID),
                loanID: try container.decode(UUID.self, forKey: .loanID),
                amount: try container.decode(Int.self, forKey: .amount)
            )
        case .endTurn:
            self = .endTurn(playerID: try container.decode(UUID.self, forKey: .playerID))
        case .skipTurn:
            self = .skipTurn
        case .acknowledgeRole:
            self = .acknowledgeRole(playerID: try container.decode(UUID.self, forKey: .playerID))
        case .drawLifeCard:
            self = .drawLifeCard(playerID: try container.decode(UUID.self, forKey: .playerID))
        case .resolveLifeCardDecision:
            self = .resolveLifeCardDecision(
                playerID: try container.decode(UUID.self, forKey: .playerID),
                accept: try container.decode(Bool.self, forKey: .accept)
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
        case let .payTravel(playerID, route):
            try container.encode(IntentType.payTravel, forKey: .type)
            try container.encode(playerID, forKey: .playerID)
            try container.encode(route, forKey: .route)
        case let .collectFreeParking(playerID):
            try container.encode(IntentType.collectFreeParking, forKey: .type)
            try container.encode(playerID, forKey: .playerID)
        case let .collectSalary(playerID, amount, postponedLoanIDs):
            try container.encode(IntentType.collectSalary, forKey: .type)
            try container.encode(playerID, forKey: .playerID)
            try container.encode(amount, forKey: .amount)
            try container.encode(postponedLoanIDs, forKey: .postponedLoanIDs)
        case let .levelUp(propertyID, playerID):
            try container.encode(IntentType.levelUp, forKey: .type)
            try container.encode(propertyID, forKey: .propertyID)
            try container.encode(playerID, forKey: .playerID)
        case let .levelDown(propertyID, playerID):
            try container.encode(IntentType.levelDown, forKey: .type)
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
        case let .proposeDeal(deal):
            try container.encode(IntentType.proposeDeal, forKey: .type)
            try container.encode(deal, forKey: .deal)
        case let .acceptDeal(dealID):
            try container.encode(IntentType.acceptDeal, forKey: .type)
            try container.encode(dealID, forKey: .dealID)
        case let .rejectDeal(dealID):
            try container.encode(IntentType.rejectDeal, forKey: .type)
            try container.encode(dealID, forKey: .dealID)
        case let .transferMoney(payerID, recipientID, amount):
            try container.encode(IntentType.transferMoney, forKey: .type)
            try container.encode(payerID, forKey: .payerID)
            try container.encode(recipientID, forKey: .recipientID)
            try container.encode(amount, forKey: .amount)
        case let .borrowOnCreditCard(playerID, amount, installments):
            try container.encode(IntentType.borrowOnCreditCard, forKey: .type)
            try container.encode(playerID, forKey: .playerID)
            try container.encode(amount, forKey: .amount)
            try container.encode(installments, forKey: .installments)
        case let .payCreditCard(playerID, loanID, amount):
            try container.encode(IntentType.payCreditCard, forKey: .type)
            try container.encode(playerID, forKey: .playerID)
            try container.encode(loanID, forKey: .loanID)
            try container.encode(amount, forKey: .amount)
        case let .endTurn(playerID):
            try container.encode(IntentType.endTurn, forKey: .type)
            try container.encode(playerID, forKey: .playerID)
        case .skipTurn:
            try container.encode(IntentType.skipTurn, forKey: .type)
        case let .acknowledgeRole(playerID):
            try container.encode(IntentType.acknowledgeRole, forKey: .type)
            try container.encode(playerID, forKey: .playerID)
        case let .drawLifeCard(playerID):
            try container.encode(IntentType.drawLifeCard, forKey: .type)
            try container.encode(playerID, forKey: .playerID)
        case let .resolveLifeCardDecision(playerID, accept):
            try container.encode(IntentType.resolveLifeCardDecision, forKey: .type)
            try container.encode(playerID, forKey: .playerID)
            try container.encode(accept, forKey: .accept)
        }
    }
}

extension GameIntent {
    // Actions tied to landing on a square or passing GO happen only on the acting
    // player's turn (GAME_RULES section 3). Raising money, trades, payments to other
    // players and bankruptcy stay available at any time.
    var requiresTurn: Bool {
        switch self {
        case .buyProperty, .resolveAuction, .collectRent, .payTax, .payTravel, .collectFreeParking,
             .collectSalary, .borrowOnCreditCard, .drawLifeCard, .resolveLifeCardDecision:
            return true
        case .levelUp, .levelDown, .mortgageProperty, .unmortgageProperty,
             .declareBankruptcy, .proposeDeal, .acceptDeal, .rejectDeal, .transferMoney, .payCreditCard,
             .endTurn, .skipTurn, .acknowledgeRole:
            return false
        }
    }
}
