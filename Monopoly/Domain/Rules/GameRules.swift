import Foundation

enum GameRules {
    static func buyProperty(
        in state: GameState,
        playerID: UUID,
        propertyID: UUID
    ) throws -> GameState {
        guard let playerIndex = state.players.firstIndex(where: { $0.id == playerID }) else {
            throw GameRuleError.playerNotFound(playerID)
        }
        try requireActivePlayer(in: state, playerID: playerID)
        guard let propertyIndex = state.properties.firstIndex(where: { $0.id == propertyID }) else {
            throw GameRuleError.propertyNotFound(propertyID)
        }

        let property = state.properties[propertyIndex]
        guard property.ownerID == nil else {
            throw GameRuleError.propertyAlreadyOwned(
                propertyID: propertyID,
                ownerID: property.ownerID!
            )
        }

        let player = state.players[playerIndex]
        guard player.balance >= property.purchasePrice else {
            throw GameRuleError.insufficientFunds(
                playerID: playerID,
                required: property.purchasePrice,
                available: player.balance
            )
        }

        var updatedState = state
        updatedState.players[playerIndex].balance -= property.purchasePrice
        updatedState.players[playerIndex].propertyIDs.append(propertyID)
        updatedState.properties[propertyIndex].ownerID = playerID
        return updatedState
    }

    static func resolveAuction(
        in state: GameState,
        propertyID: UUID,
        bids: [AuctionBid]
    ) throws -> GameState {
        guard !state.activeHouseRules.contains(.noAuction) else {
            throw GameRuleError.auctionsDisabled
        }
        guard let propertyIndex = state.properties.firstIndex(where: { $0.id == propertyID }) else {
            throw GameRuleError.propertyNotFound(propertyID)
        }

        let property = state.properties[propertyIndex]
        guard property.ownerID == nil else {
            throw GameRuleError.propertyAlreadyOwned(
                propertyID: propertyID,
                ownerID: property.ownerID!
            )
        }

        var highestBid = 0
        var winningBid: AuctionBid?

        for bid in bids {
            try requireActivePlayer(in: state, playerID: bid.playerID)
            guard bid.amount > highestBid else {
                throw GameRuleError.invalidBid
            }
            highestBid = bid.amount
            winningBid = bid
        }

        guard let winningBid else {
            return state
        }

        guard let winnerIndex = state.players.firstIndex(where: { $0.id == winningBid.playerID }) else {
            throw GameRuleError.playerNotFound(winningBid.playerID)
        }
        let winner = state.players[winnerIndex]
        guard winner.balance >= winningBid.amount else {
            throw GameRuleError.insufficientFunds(
                playerID: winningBid.playerID,
                required: winningBid.amount,
                available: winner.balance
            )
        }

        var updatedState = state
        updatedState.players[winnerIndex].balance -= winningBid.amount
        updatedState.players[winnerIndex].propertyIDs.append(propertyID)
        updatedState.properties[propertyIndex].ownerID = winningBid.playerID
        return updatedState
    }

    static func collectRent(
        in state: GameState,
        from payerID: UUID,
        propertyID: UUID
    ) throws -> RentResult {
        guard let payerIndex = state.players.firstIndex(where: { $0.id == payerID }) else {
            throw GameRuleError.playerNotFound(payerID)
        }
        try requireActivePlayer(in: state, playerID: payerID)
        guard let propertyIndex = state.properties.firstIndex(where: { $0.id == propertyID }) else {
            throw GameRuleError.propertyNotFound(propertyID)
        }

        let property = state.properties[propertyIndex]
        guard let ownerID = property.ownerID else {
            throw GameRuleError.propertyHasNoOwner(propertyID)
        }

        guard ownerID != payerID, !property.isMortgaged else {
            return RentResult(state: state, amount: 0)
        }

        guard let ownerIndex = state.players.firstIndex(where: { $0.id == ownerID }) else {
            throw GameRuleError.playerNotFound(ownerID)
        }
        try requireActivePlayer(in: state, playerID: ownerID)

        let rent = try rentAmount(for: property, in: state, ownerID: ownerID)
        let payer = state.players[payerIndex]
        guard payer.balance >= rent else {
            throw GameRuleError.insufficientFunds(
                playerID: payerID,
                required: rent,
                available: payer.balance
            )
        }

        var updatedState = state
        updatedState.players[payerIndex].balance -= rent
        updatedState.players[ownerIndex].balance += rent
        return RentResult(state: updatedState, amount: rent)
    }

    static func payTax(
        in state: GameState,
        playerID: UUID,
        amount: Int
    ) throws -> GameState {
        guard let playerIndex = state.players.firstIndex(where: { $0.id == playerID }) else {
            throw GameRuleError.playerNotFound(playerID)
        }
        try requireActivePlayer(in: state, playerID: playerID)
        guard amount >= 0 else {
            throw GameRuleError.invalidAmount(amount)
        }

        let player = state.players[playerIndex]
        guard player.balance >= amount else {
            throw GameRuleError.insufficientFunds(
                playerID: playerID,
                required: amount,
                available: player.balance
            )
        }

        var updatedState = state
        updatedState.players[playerIndex].balance -= amount
        return updatedState
    }

    static func collectSalary(
        in state: GameState,
        playerID: UUID,
        amount: Int
    ) throws -> GameState {
        guard let playerIndex = state.players.firstIndex(where: { $0.id == playerID }) else {
            throw GameRuleError.playerNotFound(playerID)
        }
        try requireActivePlayer(in: state, playerID: playerID)
        guard amount >= 0 else {
            throw GameRuleError.invalidAmount(amount)
        }

        var updatedState = state
        updatedState.players[playerIndex].balance += amount
        return updatedState
    }

    static func buildHouse(
        in state: GameState,
        propertyID: UUID,
        playerID: UUID
    ) throws -> GameState {
        let (playerIndex, propertyIndex, property) = try buildingContext(
            in: state,
            propertyID: propertyID,
            playerID: playerID
        )

        guard !property.isMortgaged else {
            throw GameRuleError.propertyIsMortgaged(propertyID)
        }
        try requireMonopoly(in: state, for: property, ownerID: playerID)
        guard property.constructionLevel < 4 else {
            if property.constructionLevel == 4 {
                throw GameRuleError.propertyHasMaximumHouses(propertyID)
            }
            throw GameRuleError.propertyAlreadyHasHotel(propertyID)
        }

        let targetLevel = property.constructionLevel + 1
        try requireUniformConstruction(in: state, for: property, targetLevel: targetLevel)

        let player = state.players[playerIndex]
        guard player.balance >= property.constructionCost else {
            throw GameRuleError.insufficientFunds(
                playerID: playerID,
                required: property.constructionCost,
                available: player.balance
            )
        }

        var updatedState = state
        updatedState.players[playerIndex].balance -= property.constructionCost
        updatedState.properties[propertyIndex].constructionLevel = targetLevel
        return updatedState
    }

    static func buildHotel(
        in state: GameState,
        propertyID: UUID,
        playerID: UUID
    ) throws -> GameState {
        let (playerIndex, propertyIndex, property) = try buildingContext(
            in: state,
            propertyID: propertyID,
            playerID: playerID
        )

        guard !property.isMortgaged else {
            throw GameRuleError.propertyIsMortgaged(propertyID)
        }
        try requireMonopoly(in: state, for: property, ownerID: playerID)
        guard property.constructionLevel == 4 else {
            if property.constructionLevel == 5 {
                throw GameRuleError.propertyAlreadyHasHotel(propertyID)
            }
            throw GameRuleError.propertyMustHaveFourHouses(propertyID)
        }

        let groupProperties = state.properties.filter { $0.colorGroup == property.colorGroup }
        guard groupProperties.allSatisfy({ $0.constructionLevel == 4 }) else {
            throw GameRuleError.propertyMustHaveFourHouses(propertyID)
        }

        let player = state.players[playerIndex]
        guard player.balance >= property.constructionCost else {
            throw GameRuleError.insufficientFunds(
                playerID: playerID,
                required: property.constructionCost,
                available: player.balance
            )
        }

        var updatedState = state
        updatedState.players[playerIndex].balance -= property.constructionCost
        updatedState.properties[propertyIndex].constructionLevel = 5
        return updatedState
    }

    static func sellHouse(
        in state: GameState,
        propertyID: UUID,
        playerID: UUID
    ) throws -> GameState {
        let (playerIndex, propertyIndex, property) = try buildingContext(
            in: state,
            propertyID: propertyID,
            playerID: playerID
        )

        guard property.constructionLevel > 0 else {
            throw GameRuleError.propertyHasNoBuildings(propertyID)
        }

        let targetLevel = property.constructionLevel - 1
        try requireUniformConstructionAfterSelling(
            in: state,
            for: property,
            targetLevel: targetLevel
        )

        // A hotel is treated as one construction level for resale: level 5 becomes level 4,
        // and the player receives half of the hotel's construction cost.
        let resaleValue = property.constructionCost / 2
        var updatedState = state
        updatedState.players[playerIndex].balance += resaleValue
        updatedState.properties[propertyIndex].constructionLevel = targetLevel
        return updatedState
    }

    static func mortgageProperty(
        in state: GameState,
        propertyID: UUID,
        playerID: UUID
    ) throws -> GameState {
        guard state.players.contains(where: { $0.id == playerID }) else {
            throw GameRuleError.playerNotFound(playerID)
        }
        try requireActivePlayer(in: state, playerID: playerID)
        guard let propertyIndex = state.properties.firstIndex(where: { $0.id == propertyID }) else {
            throw GameRuleError.propertyNotFound(propertyID)
        }

        let property = state.properties[propertyIndex]
        guard property.ownerID == playerID else {
            throw GameRuleError.propertyNotOwnedByPlayer(propertyID: propertyID, playerID: playerID)
        }
        guard property.constructionLevel == 0 else {
            throw GameRuleError.propertyHasBuildings(propertyID)
        }
        guard !property.isMortgaged else {
            throw GameRuleError.propertyAlreadyMortgaged(propertyID)
        }

        var updatedState = state
        updatedState.properties[propertyIndex].isMortgaged = true
        if let ownerIndex = updatedState.players.firstIndex(where: { $0.id == playerID }) {
            updatedState.players[ownerIndex].balance += property.mortgageValue
        }
        return updatedState
    }

    static func unmortgageProperty(
        in state: GameState,
        propertyID: UUID,
        playerID: UUID
    ) throws -> GameState {
        guard let playerIndex = state.players.firstIndex(where: { $0.id == playerID }) else {
            throw GameRuleError.playerNotFound(playerID)
        }
        try requireActivePlayer(in: state, playerID: playerID)
        guard let propertyIndex = state.properties.firstIndex(where: { $0.id == propertyID }) else {
            throw GameRuleError.propertyNotFound(propertyID)
        }

        let property = state.properties[propertyIndex]
        guard property.ownerID == playerID else {
            throw GameRuleError.propertyNotOwnedByPlayer(propertyID: propertyID, playerID: playerID)
        }
        guard property.isMortgaged else {
            throw GameRuleError.propertyIsNotMortgaged(propertyID)
        }

        let repayment = property.mortgageValue * 11 / 10
        let player = state.players[playerIndex]
        guard player.balance >= repayment else {
            throw GameRuleError.insufficientFunds(
                playerID: playerID,
                required: repayment,
                available: player.balance
            )
        }

        var updatedState = state
        updatedState.players[playerIndex].balance -= repayment
        updatedState.properties[propertyIndex].isMortgaged = false
        return updatedState
    }

    static func canCoverDebt(
        in state: GameState,
        playerID: UUID,
        debt: Debt
    ) throws -> Bool {
        guard let player = state.players.first(where: { $0.id == playerID }) else {
            throw GameRuleError.playerNotFound(playerID)
        }
        try requireActivePlayer(in: state, playerID: playerID)
        guard debt.amount >= 0 else {
            throw GameRuleError.invalidDebtAmount(debt.amount)
        }

        let liquidationValue = state.properties
            .filter { $0.ownerID == playerID }
            .reduce(0) { total, property in
                // This is a best-case estimate only: it assumes buildings are sold before
                // mortgaging an un-mortgaged property. It does not execute either action,
                // because choosing their order is a UI decision outside the domain function.
                let buildingsValue = constructionResaleValue(for: property)
                let mortgageValue = property.isMortgaged ? 0 : property.mortgageValue
                return total + buildingsValue + mortgageValue
            }

        return player.balance + liquidationValue >= debt.amount
    }

    static func declareBankruptcy(
        in state: GameState,
        playerID: UUID,
        creditor: DebtCreditor
    ) throws -> GameState {
        guard let bankruptPlayerIndex = state.players.firstIndex(where: { $0.id == playerID }) else {
            throw GameRuleError.playerNotFound(playerID)
        }
        try requireActivePlayer(in: state, playerID: playerID)

        let creditorIndex: Int?
        switch creditor {
        case .bank:
            creditorIndex = nil
        case let .player(creditorID):
            guard creditorID != playerID else {
                throw GameRuleError.invalidBankruptcyCreditor(creditorID)
            }
            guard let index = state.players.firstIndex(where: { $0.id == creditorID }) else {
                throw GameRuleError.playerNotFound(creditorID)
            }
            try requireActivePlayer(in: state, playerID: creditorID)
            creditorIndex = index
        }

        let transferredPropertyIDs = state.properties
            .filter { $0.ownerID == playerID }
            .map(\.id)
        let bankruptBalance = state.players[bankruptPlayerIndex].balance

        var updatedState = state
        updatedState.players[bankruptPlayerIndex].status = .bankrupt
        updatedState.players[bankruptPlayerIndex].balance = 0
        updatedState.players[bankruptPlayerIndex].propertyIDs.removeAll()

        for propertyID in transferredPropertyIDs {
            guard let propertyIndex = updatedState.properties.firstIndex(where: { $0.id == propertyID }) else {
                continue
            }

            switch creditor {
            case .bank:
                updatedState.properties[propertyIndex].ownerID = nil
                updatedState.properties[propertyIndex].constructionLevel = 0
                updatedState.properties[propertyIndex].isMortgaged = false
            case .player:
                updatedState.properties[propertyIndex].ownerID = creditorIndex.map { updatedState.players[$0].id }
            }
        }

        for index in updatedState.players.indices {
            updatedState.players[index].propertyIDs.removeAll { transferredPropertyIDs.contains($0) }
        }

        if let creditorIndex = creditorIndex {
            updatedState.players[creditorIndex].balance += bankruptBalance
            updatedState.players[creditorIndex].propertyIDs.append(contentsOf: transferredPropertyIDs)
        }

        return updatedState
    }

    static func executeTrade(
        in state: GameState,
        offer: TradeOffer
    ) throws -> GameState {
        guard offer.fromPlayerID != offer.toPlayerID else {
            throw GameRuleError.tradeParticipantsMustDiffer
        }
        guard let fromPlayerIndex = state.players.firstIndex(where: { $0.id == offer.fromPlayerID }) else {
            throw GameRuleError.playerNotFound(offer.fromPlayerID)
        }
        guard let toPlayerIndex = state.players.firstIndex(where: { $0.id == offer.toPlayerID }) else {
            throw GameRuleError.playerNotFound(offer.toPlayerID)
        }
        try requireActivePlayer(in: state, playerID: offer.fromPlayerID)
        try requireActivePlayer(in: state, playerID: offer.toPlayerID)
        try requireNonNegativeTradeAmounts(in: offer)

        let allPropertyIDs = offer.offeredPropertyIDs + offer.requestedPropertyIDs
        try requireUniqueTradePropertyIDs(allPropertyIDs)
        try requireTradeProperties(
            in: state,
            propertyIDs: offer.offeredPropertyIDs,
            ownedBy: offer.fromPlayerID
        )
        try requireTradeProperties(
            in: state,
            propertyIDs: offer.requestedPropertyIDs,
            ownedBy: offer.toPlayerID
        )

        let fromPlayer = state.players[fromPlayerIndex]
        let toPlayer = state.players[toPlayerIndex]
        guard fromPlayer.balance >= offer.offeredMoney else {
            throw GameRuleError.insufficientFunds(
                playerID: offer.fromPlayerID,
                required: offer.offeredMoney,
                available: fromPlayer.balance
            )
        }
        guard toPlayer.balance >= offer.requestedMoney else {
            throw GameRuleError.insufficientFunds(
                playerID: offer.toPlayerID,
                required: offer.requestedMoney,
                available: toPlayer.balance
            )
        }

        var updatedState = state
        updatedState.players[fromPlayerIndex].balance += offer.requestedMoney - offer.offeredMoney
        updatedState.players[toPlayerIndex].balance += offer.offeredMoney - offer.requestedMoney

        for propertyID in offer.offeredPropertyIDs {
            transferProperty(in: &updatedState, propertyID: propertyID, to: offer.toPlayerID)
        }
        for propertyID in offer.requestedPropertyIDs {
            transferProperty(in: &updatedState, propertyID: propertyID, to: offer.fromPlayerID)
        }

        return updatedState
    }

    static func rentAmount(
        for property: Property,
        in state: GameState,
        ownerID: UUID
    ) throws -> Int {
        if property.constructionLevel == 0 {
            let groupProperties = state.properties.filter { $0.colorGroup == property.colorGroup }
            let ownsMonopoly = groupProperties.count >= 2 && groupProperties.allSatisfy { $0.ownerID == ownerID }
            return ownsMonopoly ? property.baseRent * 2 : property.baseRent
        }

        guard property.rentByConstructionLevel.indices.contains(property.constructionLevel) else {
            throw GameRuleError.invalidRentTable(property.id)
        }
        return property.rentByConstructionLevel[property.constructionLevel]
    }

    private static func buildingContext(
        in state: GameState,
        propertyID: UUID,
        playerID: UUID
    ) throws -> (playerIndex: Int, propertyIndex: Int, property: Property) {
        guard let playerIndex = state.players.firstIndex(where: { $0.id == playerID }) else {
            throw GameRuleError.playerNotFound(playerID)
        }
        try requireActivePlayer(in: state, playerID: playerID)
        guard let propertyIndex = state.properties.firstIndex(where: { $0.id == propertyID }) else {
            throw GameRuleError.propertyNotFound(propertyID)
        }

        let property = state.properties[propertyIndex]
        guard property.ownerID == playerID else {
            throw GameRuleError.propertyNotOwnedByPlayer(propertyID: propertyID, playerID: playerID)
        }
        return (playerIndex, propertyIndex, property)
    }

    private static func requireMonopoly(
        in state: GameState,
        for property: Property,
        ownerID: UUID
    ) throws {
        let groupProperties = state.properties.filter { $0.colorGroup == property.colorGroup }
        guard groupProperties.count >= 2, groupProperties.allSatisfy({ $0.ownerID == ownerID }) else {
            throw GameRuleError.playerDoesNotOwnMonopoly(property.colorGroup)
        }
    }

    private static func requireUniformConstruction(
        in state: GameState,
        for property: Property,
        targetLevel: Int
    ) throws {
        let groupProperties = state.properties.filter { $0.colorGroup == property.colorGroup }
        guard groupProperties.allSatisfy({
            let level = $0.id == property.id ? targetLevel : $0.constructionLevel
            return abs(targetLevel - level) <= 1
        }) else {
            throw GameRuleError.violatesUniformConstruction(property.id)
        }
    }

    private static func requireUniformConstructionAfterSelling(
        in state: GameState,
        for property: Property,
        targetLevel: Int
    ) throws {
        let groupProperties = state.properties.filter { $0.colorGroup == property.colorGroup }
        let levels = groupProperties.map {
            $0.id == property.id ? targetLevel : $0.constructionLevel
        }
        guard let minimumLevel = levels.min(), let maximumLevel = levels.max(), maximumLevel - minimumLevel <= 1 else {
            throw GameRuleError.violatesUniformConstruction(property.id)
        }
    }

    private static func constructionResaleValue(for property: Property) -> Int {
        // Matches sellHouse: every construction level (houses and the hotel alike)
        // resells for half of constructionCost, one level at a time, so fully
        // liquidating a property is constructionLevel * constructionCost / 2.
        guard property.constructionLevel > 0 else { return 0 }
        return property.constructionLevel * property.constructionCost / 2
    }

    private static func requireActivePlayer(in state: GameState, playerID: UUID) throws {
        guard let player = state.players.first(where: { $0.id == playerID }) else {
            throw GameRuleError.playerNotFound(playerID)
        }
        guard player.status == .active else {
            throw GameRuleError.playerIsBankrupt(playerID)
        }
    }

    private static func requireNonNegativeTradeAmounts(in offer: TradeOffer) throws {
        guard offer.offeredMoney >= 0 else {
            throw GameRuleError.invalidAmount(offer.offeredMoney)
        }
        guard offer.requestedMoney >= 0 else {
            throw GameRuleError.invalidAmount(offer.requestedMoney)
        }
    }

    private static func requireUniqueTradePropertyIDs(_ propertyIDs: [UUID]) throws {
        var seen = Set<UUID>()
        for propertyID in propertyIDs {
            guard seen.insert(propertyID).inserted else {
                throw GameRuleError.duplicateTradeProperty(propertyID)
            }
        }
    }

    private static func requireTradeProperties(
        in state: GameState,
        propertyIDs: [UUID],
        ownedBy playerID: UUID
    ) throws {
        for propertyID in propertyIDs {
            guard let property = state.properties.first(where: { $0.id == propertyID }) else {
                throw GameRuleError.propertyNotFound(propertyID)
            }
            guard property.ownerID == playerID else {
                throw GameRuleError.propertyNotOwnedByPlayer(
                    propertyID: propertyID,
                    playerID: playerID
                )
            }
        }
    }

    private static func transferProperty(
        in state: inout GameState,
        propertyID: UUID,
        to playerID: UUID
    ) {
        guard let propertyIndex = state.properties.firstIndex(where: { $0.id == propertyID }),
              let playerIndex = state.players.firstIndex(where: { $0.id == playerID }) else {
            return
        }

        for index in state.players.indices {
            state.players[index].propertyIDs.removeAll { $0 == propertyID }
        }
        state.properties[propertyIndex].ownerID = playerID
        state.players[playerIndex].propertyIDs.append(propertyID)
    }
}
