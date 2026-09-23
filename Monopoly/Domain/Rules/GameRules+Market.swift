import Foundation

// Market: players propose deals that move money and property shares between any
// number of players (GAME_RULES section 4.6). A deal settles, all at once, when
// every participant has accepted; an open offer settles as soon as anyone takes it.
extension GameRules {
    static func proposeDeal(
        in state: GameState,
        deal: MarketDeal,
        proposerID: UUID
    ) throws -> GameState {
        try requireActivePlayer(in: state, playerID: proposerID)
        guard !state.marketDeals.contains(where: { $0.id == deal.id }) else {
            throw GameRuleError.invalidDeal
        }

        let proposedDeal = MarketDeal(
            id: deal.id,
            proposerID: proposerID,
            transfers: deal.transfers,
            sharedPurchase: deal.sharedPurchase,
            proposedInvestment: deal.proposedInvestment,
            cancelInvestment: deal.cancelInvestment,
            acceptedBy: [proposerID]
        )
        try validateStructure(of: proposedDeal, in: state)

        // Buying from the bank belongs to the turn of the player who landed there.
        if proposedDeal.sharedPurchase != nil {
            try requireTurn(in: state, playerID: proposerID)
        }

        // Catch deals that could never settle right away instead of when the last
        // participant accepts. An open offer can only be checked on the proposer's side.
        if proposedDeal.isOpenOffer {
            try requireProposerCanDeliver(proposedDeal, in: state)
        } else {
            _ = try settle(proposedDeal, in: state)
        }

        var updatedState = state
        updatedState.marketDeals.append(proposedDeal)
        return updatedState
    }

    static func acceptDeal(
        in state: GameState,
        dealID: UUID,
        playerID: UUID
    ) throws -> GameState {
        guard let dealIndex = state.marketDeals.firstIndex(where: { $0.id == dealID }) else {
            throw GameRuleError.dealNotFound(dealID)
        }
        try requireActivePlayer(in: state, playerID: playerID)
        let deal = state.marketDeals[dealIndex]

        if deal.isOpenOffer {
            guard playerID != deal.proposerID else {
                throw GameRuleError.cannotAcceptOwnOffer
            }
            var updatedState = try settle(deal.resolvingTaker(playerID), in: state)
            updatedState.marketDeals.removeAll { $0.id == dealID }
            return updatedState
        }

        guard deal.participantIDs.contains(playerID) else {
            throw GameRuleError.notDealParticipant(playerID)
        }

        var acceptedDeal = deal
        acceptedDeal.acceptedBy.insert(playerID)
        guard acceptedDeal.pendingPlayerIDs.isEmpty else {
            var updatedState = state
            updatedState.marketDeals[dealIndex] = acceptedDeal
            return updatedState
        }

        do {
            var updatedState = try settle(acceptedDeal, in: state)
            updatedState.marketDeals.removeAll { $0.id == dealID }
            return updatedState
        } catch let error as GameRuleError where error.isDealStaleness {
            // Something the deal depends on (shares, an investment's available
            // percentage, a balance, a shared purchase's target) changed after
            // everyone but this player had already accepted. The deal can no longer
            // settle as proposed, so it is withdrawn here instead of sitting in
            // marketDeals forever, forever failing this same way and needing someone
            // to notice and reject it. Any other error is a real failure (malformed
            // deal, missing player/property) and is surfaced to the caller as-is,
            // leaving the deal in place.
            var updatedState = state
            updatedState.marketDeals.removeAll { $0.id == dealID }
            return updatedState
        }
    }

    /// Any participant can turn a deal down, which withdraws it for everyone. An open
    /// offer can only be withdrawn by its proposer; others simply don't take it.
    static func rejectDeal(
        in state: GameState,
        dealID: UUID,
        playerID: UUID
    ) throws -> GameState {
        guard let deal = state.marketDeals.first(where: { $0.id == dealID }) else {
            throw GameRuleError.dealNotFound(dealID)
        }
        let canReject = deal.isOpenOffer ? playerID == deal.proposerID : deal.participantIDs.contains(playerID)
        guard canReject else {
            throw GameRuleError.notDealParticipant(playerID)
        }

        var updatedState = state
        updatedState.marketDeals.removeAll { $0.id == dealID }
        return updatedState
    }

    /// Applies every transfer and the shared purchase at once. Balances and shares are
    /// checked on the net result, so a player may pay with money received in the same
    /// deal; nothing changes unless everything can.
    static func settle(_ deal: MarketDeal, in state: GameState) throws -> GameState {
        try validateStructure(of: deal, in: state)

        var moneyChanges: [UUID: Int] = [:]
        var shareChanges: [UUID: [(playerID: UUID, count: Int)]] = [:]

        for transfer in deal.transfers {
            guard let fromID = transfer.from.playerID, let toID = transfer.to.playerID else {
                throw GameRuleError.invalidDeal
            }
            switch transfer.asset {
            case let .money(amount):
                moneyChanges[fromID, default: 0] -= amount
                moneyChanges[toID, default: 0] += amount
            case let .shares(propertyID, count):
                shareChanges[propertyID, default: []].append((fromID, -count))
                shareChanges[propertyID, default: []].append((toID, count))
            }
        }

        var updatedState = state

        if let purchase = deal.sharedPurchase {
            guard let propertyIndex = state.properties.firstIndex(where: { $0.id == purchase.propertyID }) else {
                throw GameRuleError.propertyNotFound(purchase.propertyID)
            }
            let property = state.properties[propertyIndex]
            if let ownerID = property.ownerID {
                throw GameRuleError.propertyAlreadyOwned(propertyID: property.id, ownerID: ownerID)
            }
            for portion in split(property.purchasePrice, among: purchase.buyers) {
                moneyChanges[portion.playerID, default: 0] -= portion.amount
            }
            updatedState.properties[propertyIndex].ownership = purchase.buyers
        }

        for (playerID, change) in moneyChanges {
            try requireActivePlayer(in: state, playerID: playerID)
            guard let player = state.players.first(where: { $0.id == playerID }) else {
                throw GameRuleError.playerNotFound(playerID)
            }
            guard player.balance + change >= 0 else {
                throw GameRuleError.insufficientFunds(
                    playerID: playerID,
                    required: -change,
                    available: player.balance
                )
            }
        }

        for (propertyID, changes) in shareChanges {
            guard let propertyIndex = updatedState.properties.firstIndex(where: { $0.id == propertyID }) else {
                throw GameRuleError.propertyNotFound(propertyID)
            }
            var property = updatedState.properties[propertyIndex]
            let netChanges = Dictionary(changes.map { ($0.playerID, $0.count) }, uniquingKeysWith: +)
            for (playerID, change) in netChanges where change < 0 {
                try requireActivePlayer(in: state, playerID: playerID)
                guard property.shares(of: playerID) + change >= 0 else {
                    throw GameRuleError.notEnoughShares(propertyID: propertyID, playerID: playerID)
                }
                property.removeShares(-change, from: playerID)
            }
            // Receivers join the shareholder list in the order they appear in the deal.
            var receivers = Set<UUID>()
            for change in changes {
                let netChange = netChanges[change.playerID] ?? 0
                guard netChange > 0, receivers.insert(change.playerID).inserted else {
                    continue
                }
                try requireActivePlayer(in: state, playerID: change.playerID)
                property.addShares(netChange, to: change.playerID)
            }
            updatedState.properties[propertyIndex] = property
        }

        for (playerID, change) in moneyChanges {
            credit(change, to: playerID, in: &updatedState)
        }

        if let investment = deal.cancelInvestment {
            updatedState.rentInvestments.removeAll { $0.id == investment.id }
        }
        if let investment = deal.proposedInvestment {
            updatedState.rentInvestments.append(investment)
        }
        reindexPropertyIDs(in: &updatedState)
        return updatedState
    }

    private static func validateStructure(of deal: MarketDeal, in state: GameState) throws {
        guard !deal.transfers.isEmpty
                || deal.sharedPurchase != nil
                || deal.proposedInvestment != nil
                || deal.cancelInvestment != nil else {
            throw GameRuleError.invalidDeal
        }

        guard !(deal.proposedInvestment != nil && deal.cancelInvestment != nil) else {
            throw GameRuleError.invalidDeal
        }

        if deal.proposedInvestment != nil || deal.cancelInvestment != nil {
            guard !deal.isOpenOffer else {
                throw GameRuleError.invalidDeal
            }
        }

        for transfer in deal.transfers {
            guard transfer.from != transfer.to else {
                throw GameRuleError.invalidDeal
            }
            // An open offer only trades between the proposer and whoever takes it.
            if deal.isOpenOffer {
                let parties: Set<DealParty> = [transfer.from, transfer.to]
                guard parties == [.player(deal.proposerID), .taker] else {
                    throw GameRuleError.invalidDeal
                }
            }
            for party in [transfer.from, transfer.to] {
                if let playerID = party.playerID {
                    try requireActivePlayer(in: state, playerID: playerID)
                }
            }
            switch transfer.asset {
            case let .money(amount):
                guard amount > 0 else {
                    throw GameRuleError.invalidAmount(amount)
                }
            case let .shares(propertyID, count):
                guard state.properties.contains(where: { $0.id == propertyID }) else {
                    throw GameRuleError.propertyNotFound(propertyID)
                }
                guard (1...Property.totalShares).contains(count) else {
                    throw GameRuleError.invalidDeal
                }
            }
        }

        if let purchase = deal.sharedPurchase {
            guard !deal.isOpenOffer,
                  purchase.buyers.count >= 2,
                  Set(purchase.buyers.map(\.playerID)).count == purchase.buyers.count,
                  purchase.buyers.allSatisfy({ $0.shares > 0 }),
                  purchase.buyers.reduce(0, { $0 + $1.shares }) == Property.totalShares,
                  purchase.buyers.contains(where: { $0.playerID == deal.proposerID }) else {
                throw GameRuleError.invalidDeal
            }
            for buyer in purchase.buyers {
                try requireActivePlayer(in: state, playerID: buyer.playerID)
            }
        }

        if let investment = deal.proposedInvestment {
            guard investment.investorID != investment.recipientID else {
                throw GameRuleError.invalidDeal
            }
            guard (1...100).contains(investment.percentage) else {
                throw GameRuleError.invalidRentInvestmentPercentage(investment.percentage)
            }
            try requireActivePlayer(in: state, playerID: investment.investorID)
            try requireActivePlayer(in: state, playerID: investment.recipientID)
            guard let property = state.properties.first(where: { $0.id == investment.propertyID }) else {
                throw GameRuleError.propertyNotFound(investment.propertyID)
            }
            guard property.shares(of: investment.recipientID) > 0 else {
                throw GameRuleError.propertyNotOwnedByPlayer(
                    propertyID: investment.propertyID,
                    playerID: investment.recipientID
                )
            }
            guard !state.rentInvestments.contains(where: { $0.id == investment.id }) else {
                throw GameRuleError.invalidDeal
            }

            let existingPercentage = state.rentInvestments
                .filter {
                    $0.propertyID == investment.propertyID
                        && $0.recipientID == investment.recipientID
                }
                .reduce(0) { $0 + $1.percentage }
            let available = max(0, 100 - existingPercentage)
            guard investment.percentage <= available else {
                throw GameRuleError.rentInvestmentPercentageExceeded(
                    propertyID: investment.propertyID,
                    recipientID: investment.recipientID,
                    requested: investment.percentage,
                    available: available
                )
            }

            // Exactly one money transfer from investor to recipient, so it is
            // unambiguously the investment's single payment and not conflated with
            // some unrelated transfer between the same two players in this deal.
            let paymentTransferCount = deal.transfers.filter {
                guard $0.from == .player(investment.investorID),
                      $0.to == .player(investment.recipientID) else {
                    return false
                }
                if case let .money(amount) = $0.asset {
                    return amount > 0
                }
                return false
            }.count
            guard paymentTransferCount == 1 else {
                throw GameRuleError.invalidDeal
            }
        }

        if let investment = deal.cancelInvestment {
            guard deal.transfers.isEmpty, deal.sharedPurchase == nil else {
                throw GameRuleError.invalidDeal
            }
            guard let activeInvestment = state.rentInvestments.first(where: { $0.id == investment.id }) else {
                throw GameRuleError.rentInvestmentNotFound(investment.id)
            }
            guard activeInvestment == investment else {
                throw GameRuleError.invalidDeal
            }
            try requireActivePlayer(in: state, playerID: investment.investorID)
            try requireActivePlayer(in: state, playerID: investment.recipientID)
            guard deal.proposerID == investment.investorID || deal.proposerID == investment.recipientID else {
                throw GameRuleError.notDealParticipant(deal.proposerID)
            }
        }

        // The proposer must be part of the deal, and a closed deal needs someone else.
        let others = deal.participantIDs.subtracting([deal.proposerID])
        guard deal.isOpenOffer || !others.isEmpty else {
            throw GameRuleError.invalidDeal
        }
        let proposerTakesPart = deal.transfers.contains {
            $0.from == .player(deal.proposerID) || $0.to == .player(deal.proposerID)
        } || deal.sharedPurchase != nil
            || deal.proposedInvestment?.investorID == deal.proposerID
            || deal.proposedInvestment?.recipientID == deal.proposerID
            || deal.cancelInvestment?.investorID == deal.proposerID
            || deal.cancelInvestment?.recipientID == deal.proposerID
        guard proposerTakesPart else {
            throw GameRuleError.invalidDeal
        }
    }

    private static func requireProposerCanDeliver(_ deal: MarketDeal, in state: GameState) throws {
        guard let proposer = state.players.first(where: { $0.id == deal.proposerID }) else {
            throw GameRuleError.playerNotFound(deal.proposerID)
        }

        var moneyOut = 0
        var sharesOut: [UUID: Int] = [:]
        for transfer in deal.transfers where transfer.from == .player(deal.proposerID) {
            switch transfer.asset {
            case let .money(amount):
                moneyOut += amount
            case let .shares(propertyID, count):
                sharesOut[propertyID, default: 0] += count
            }
        }

        guard proposer.balance >= moneyOut else {
            throw GameRuleError.insufficientFunds(
                playerID: proposer.id,
                required: moneyOut,
                available: proposer.balance
            )
        }
        for (propertyID, count) in sharesOut {
            let owned = state.properties.first(where: { $0.id == propertyID })?.shares(of: proposer.id) ?? 0
            guard owned >= count else {
                throw GameRuleError.notEnoughShares(propertyID: propertyID, playerID: proposer.id)
            }
        }
    }
}
