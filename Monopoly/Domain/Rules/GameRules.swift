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
        amount: Int,
        postponedLoanIDs: Set<UUID> = []
    ) throws -> GameState {
        guard let playerIndex = state.players.firstIndex(where: { $0.id == playerID }) else {
            throw GameRuleError.playerNotFound(playerID)
        }
        try requireActivePlayer(in: state, playerID: playerID)
        guard amount >= 0 else {
            throw GameRuleError.invalidAmount(amount)
        }

        let loans = state.players[playerIndex].creditCardLoans
        for loanID in postponedLoanIDs {
            guard let loan = loans.first(where: { $0.id == loanID }) else {
                throw GameRuleError.creditCardLoanNotFound(loanID)
            }
            guard loan.postponementsRemaining > 0 else {
                throw GameRuleError.noPostponementsLeft(loanID)
            }
        }

        var updatedState = state
        var player = updatedState.players[playerIndex]
        player.balance += amount

        for index in player.creditCardLoans.indices {
            if postponedLoanIDs.contains(player.creditCardLoans[index].id) {
                player.creditCardLoans[index].postponementsRemaining -= 1
                continue
            }

            let payment = min(creditCardInstallmentDue(for: player.creditCardLoans[index]), player.balance)
            player.balance -= payment
            player.creditCardLoans[index].remainingDebt -= payment
            // The last installment stays open until paid, so an unpaid remainder is due
            // in full at the next GO instead of disappearing from the schedule.
            if player.creditCardLoans[index].installmentsRemaining > 1 {
                player.creditCardLoans[index].installmentsRemaining -= 1
            }
        }
        player.creditCardLoans.removeAll { $0.remainingDebt <= 0 }

        updatedState.players[playerIndex] = player
        return updatedState
    }

    static func netWorth(of playerID: UUID, in state: GameState) throws -> Int {
        guard let player = state.players.first(where: { $0.id == playerID }) else {
            throw GameRuleError.playerNotFound(playerID)
        }

        let propertiesValue = state.properties
            .filter { $0.ownerID == playerID && !$0.isMortgaged }
            .reduce(0) { total, property in
                total + property.purchasePrice + property.constructionLevel * property.constructionCost
            }
        return player.balance + propertiesValue - player.creditCardDebt
    }

    // Net worth already subtracts the debt, and the debt is subtracted again from the
    // 50% limit. Otherwise borrowed cash would count as net worth and repeated loans
    // could grow without bound.
    static func availableCredit(for playerID: UUID, in state: GameState) throws -> Int {
        guard let player = state.players.first(where: { $0.id == playerID }) else {
            throw GameRuleError.playerNotFound(playerID)
        }
        let limit = try netWorth(of: playerID, in: state) / 2
        return max(0, limit - player.creditCardDebt)
    }

    static func creditCardDebt(forLoan amount: Int) -> Int {
        amount * 11 / 10
    }

    static let maxCreditCardInstallments = 5

    // Rounded up so the installments always cover the whole debt.
    static func creditCardInstallmentDue(for loan: CreditCardLoan) -> Int {
        guard loan.installmentsRemaining > 1 else {
            return loan.remainingDebt
        }
        return (loan.remainingDebt + loan.installmentsRemaining - 1) / loan.installmentsRemaining
    }

    static func borrowOnCreditCard(
        in state: GameState,
        playerID: UUID,
        amount: Int,
        installments: Int
    ) throws -> GameState {
        guard state.activeHouseRules.contains(.creditCards) else {
            throw GameRuleError.creditCardsDisabled
        }
        guard let playerIndex = state.players.firstIndex(where: { $0.id == playerID }) else {
            throw GameRuleError.playerNotFound(playerID)
        }
        try requireActivePlayer(in: state, playerID: playerID)
        guard amount > 0 else {
            throw GameRuleError.invalidAmount(amount)
        }
        guard (1...maxCreditCardInstallments).contains(installments) else {
            throw GameRuleError.invalidInstallments(installments)
        }

        let available = try availableCredit(for: playerID, in: state)
        guard amount <= available else {
            throw GameRuleError.creditLimitExceeded(requested: amount, available: available)
        }

        var updatedState = state
        updatedState.players[playerIndex].balance += amount
        updatedState.players[playerIndex].creditCardLoans.append(CreditCardLoan(
            remainingDebt: creditCardDebt(forLoan: amount),
            installmentsRemaining: installments,
            postponementsRemaining: maxCreditCardInstallments - installments
        ))
        return updatedState
    }

    static func payCreditCard(
        in state: GameState,
        playerID: UUID,
        loanID: UUID,
        amount: Int
    ) throws -> GameState {
        guard let playerIndex = state.players.firstIndex(where: { $0.id == playerID }) else {
            throw GameRuleError.playerNotFound(playerID)
        }
        try requireActivePlayer(in: state, playerID: playerID)

        let player = state.players[playerIndex]
        guard let loanIndex = player.creditCardLoans.firstIndex(where: { $0.id == loanID }) else {
            throw GameRuleError.creditCardLoanNotFound(loanID)
        }
        guard amount > 0, amount <= player.creditCardLoans[loanIndex].remainingDebt else {
            throw GameRuleError.invalidAmount(amount)
        }
        guard player.balance >= amount else {
            throw GameRuleError.insufficientFunds(
                playerID: playerID,
                required: amount,
                available: player.balance
            )
        }

        var updatedState = state
        updatedState.players[playerIndex].balance -= amount
        updatedState.players[playerIndex].creditCardLoans[loanIndex].remainingDebt -= amount
        updatedState.players[playerIndex].creditCardLoans.removeAll { $0.remainingDebt <= 0 }
        return updatedState
    }

    static func transferMoney(
        in state: GameState,
        from payerID: UUID,
        to recipientID: UUID,
        amount: Int
    ) throws -> GameState {
        guard payerID != recipientID else {
            throw GameRuleError.transferParticipantsMustDiffer
        }
        guard let payerIndex = state.players.firstIndex(where: { $0.id == payerID }) else {
            throw GameRuleError.playerNotFound(payerID)
        }
        guard let recipientIndex = state.players.firstIndex(where: { $0.id == recipientID }) else {
            throw GameRuleError.playerNotFound(recipientID)
        }
        try requireActivePlayer(in: state, playerID: payerID)
        try requireActivePlayer(in: state, playerID: recipientID)
        guard amount > 0 else {
            throw GameRuleError.invalidAmount(amount)
        }

        let payer = state.players[payerIndex]
        guard payer.balance >= amount else {
            throw GameRuleError.insufficientFunds(
                playerID: payerID,
                required: amount,
                available: payer.balance
            )
        }

        var updatedState = state
        updatedState.players[payerIndex].balance -= amount
        updatedState.players[recipientIndex].balance += amount
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
        updatedState.players[bankruptPlayerIndex].creditCardLoans.removeAll()
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

        if updatedState.currentPlayerID == playerID {
            updatedState = advanceTurn(in: updatedState)
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

    // A state without a current player (e.g. built directly in tests) has no turn order,
    // so nothing is gated by turn.
    static func requireTurn(in state: GameState, playerID: UUID) throws {
        guard let currentPlayerID = state.currentPlayerID else {
            return
        }
        guard currentPlayerID == playerID else {
            throw GameRuleError.notPlayersTurn(currentPlayerID: currentPlayerID)
        }
    }

    static func endTurn(in state: GameState, playerID: UUID) throws -> GameState {
        try requireTurn(in: state, playerID: playerID)
        return advanceTurn(in: state)
    }

    // Turn order is the order of `players`; bankrupt players are skipped, and wrapping
    // past the last player starts a new round.
    static func advanceTurn(in state: GameState) -> GameState {
        guard let currentPlayerID = state.currentPlayerID,
              let currentIndex = state.players.firstIndex(where: { $0.id == currentPlayerID }) else {
            return state
        }

        for offset in 1...state.players.count {
            let nextIndex = (currentIndex + offset) % state.players.count
            guard state.players[nextIndex].status == .active else {
                continue
            }

            var updatedState = state
            if currentIndex + offset >= state.players.count {
                updatedState.round += 1
            }
            updatedState.currentPlayerID = state.players[nextIndex].id
            return updatedState
        }
        return state
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
