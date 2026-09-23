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
        updatedState.properties[propertyIndex].ownership = [PropertyShare(playerID: playerID, shares: Property.totalShares)]
        updatedState.marketDeals.removeAll { $0.sharedPurchase?.propertyID == propertyID }
        reindexPropertyIDs(in: &updatedState)
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
        updatedState.properties[propertyIndex].ownership = [
            PropertyShare(playerID: winningBid.playerID, shares: Property.totalShares)
        ]
        updatedState.marketDeals.removeAll { $0.sharedPurchase?.propertyID == propertyID }
        reindexPropertyIDs(in: &updatedState)
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

        guard !property.isMortgaged else {
            return RentResult(state: state, amount: 0)
        }
        for holding in property.ownership where holding.playerID != payerID {
            try requireActivePlayer(in: state, playerID: holding.playerID)
        }

        // Rent is split among all shareholders by their stake; a payer who holds
        // shares only pays the other shareholders' portions.
        let rent = try rentAmount(for: property, in: state, ownerID: ownerID)
        let portions = split(rent, among: property.ownership).filter { $0.playerID != payerID }
        let amountDue = portions.reduce(0) { $0 + $1.amount }
        guard amountDue > 0 else {
            return RentResult(state: state, amount: 0)
        }

        let payer = state.players[payerIndex]
        guard payer.balance >= amountDue else {
            throw GameRuleError.insufficientFunds(
                playerID: payerID,
                required: amountDue,
                available: payer.balance
            )
        }

        var updatedState = state
        updatedState.players[payerIndex].balance -= amountDue
        for portion in portions {
            credit(portion.amount, to: portion.playerID, in: &updatedState)
        }
        return RentResult(state: updatedState, amount: amountDue)
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
            .filter { !$0.isMortgaged }
            .reduce(0) { total, property in
                let fullValue = property.purchasePrice + property.constructionLevel * property.constructionCost
                return total + fullValue * property.shares(of: playerID) / Property.totalShares
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
        let (propertyIndex, property) = try buildingContext(
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

        var updatedState = state
        try chargeShareholders(property.constructionCost, of: property, in: &updatedState)
        updatedState.properties[propertyIndex].constructionLevel = targetLevel
        return updatedState
    }

    static func buildHotel(
        in state: GameState,
        propertyID: UUID,
        playerID: UUID
    ) throws -> GameState {
        let (propertyIndex, property) = try buildingContext(
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

        var updatedState = state
        try chargeShareholders(property.constructionCost, of: property, in: &updatedState)
        updatedState.properties[propertyIndex].constructionLevel = 5
        return updatedState
    }

    static func sellHouse(
        in state: GameState,
        propertyID: UUID,
        playerID: UUID
    ) throws -> GameState {
        let (propertyIndex, property) = try buildingContext(
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
        // and the shareholders receive half of the hotel's construction cost.
        let resaleValue = property.constructionCost / 2
        var updatedState = state
        payShareholders(resaleValue, of: property, in: &updatedState)
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
        payShareholders(property.mortgageValue, of: property, in: &updatedState)
        return updatedState
    }

    static func unmortgageProperty(
        in state: GameState,
        propertyID: UUID,
        playerID: UUID
    ) throws -> GameState {
        let (propertyIndex, property) = try buildingContext(in: state, propertyID: propertyID, playerID: playerID)
        guard property.isMortgaged else {
            throw GameRuleError.propertyIsNotMortgaged(propertyID)
        }

        let repayment = property.mortgageValue * 11 / 10
        var updatedState = state
        try chargeShareholders(repayment, of: property, in: &updatedState)
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
            .filter { $0.shares(of: playerID) > 0 }
            .reduce(0) { total, property in
                // This is a best-case estimate only: it assumes buildings are sold before
                // mortgaging an un-mortgaged property, and counts only the player's share
                // of what the shareholders would receive. It does not execute either
                // action, because choosing their order is a UI decision outside the domain.
                let buildingsValue = constructionResaleValue(for: property)
                let mortgageValue = property.isMortgaged ? 0 : property.mortgageValue
                return total + (buildingsValue + mortgageValue) * property.shares(of: playerID) / Property.totalShares
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

        let bankruptBalance = state.players[bankruptPlayerIndex].balance

        var updatedState = state
        updatedState.players[bankruptPlayerIndex].status = .bankrupt
        updatedState.players[bankruptPlayerIndex].balance = 0
        updatedState.players[bankruptPlayerIndex].creditCardLoans.removeAll()

        for propertyIndex in updatedState.properties.indices {
            let shares = updatedState.properties[propertyIndex].shares(of: playerID)
            guard shares > 0 else {
                continue
            }
            updatedState.properties[propertyIndex].removeShares(shares, from: playerID)

            switch creditor {
            case let .player(creditorID):
                updatedState.properties[propertyIndex].addShares(shares, to: creditorID)
            case .bank:
                let remainingShareholders = updatedState.properties[propertyIndex].ownership
                if remainingShareholders.isEmpty {
                    updatedState.properties[propertyIndex].constructionLevel = 0
                    updatedState.properties[propertyIndex].isMortgaged = false
                } else {
                    // The bank never holds part of a property: the bankrupt player's
                    // shares go to the remaining shareholders in proportion to their stakes.
                    for portion in split(shares, among: remainingShareholders) {
                        updatedState.properties[propertyIndex].addShares(portion.amount, to: portion.playerID)
                    }
                }
            }
        }

        if let creditorIndex = creditorIndex {
            updatedState.players[creditorIndex].balance += bankruptBalance
        }
        updatedState.marketDeals.removeAll { $0.participantIDs.contains(playerID) }
        reindexPropertyIDs(in: &updatedState)

        if updatedState.currentPlayerID == playerID {
            updatedState = advanceTurn(in: updatedState)
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
    ) throws -> (propertyIndex: Int, property: Property) {
        try requireActivePlayer(in: state, playerID: playerID)
        guard let propertyIndex = state.properties.firstIndex(where: { $0.id == propertyID }) else {
            throw GameRuleError.propertyNotFound(propertyID)
        }

        let property = state.properties[propertyIndex]
        guard property.ownerID == playerID else {
            throw GameRuleError.propertyNotOwnedByPlayer(propertyID: propertyID, playerID: playerID)
        }
        return (propertyIndex, property)
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

    static func requireActivePlayer(in state: GameState, playerID: UUID) throws {
        guard let player = state.players.first(where: { $0.id == playerID }) else {
            throw GameRuleError.playerNotFound(playerID)
        }
        guard player.status == .active else {
            throw GameRuleError.playerIsBankrupt(playerID)
        }
    }

    /// Splits `amount` among shareholders in proportion to their shares, using the
    /// largest-remainder method so the portions always add up to `amount`; ties in
    /// the remainder go to the earlier shareholder.
    static func split(_ amount: Int, among holdings: [PropertyShare]) -> [(playerID: UUID, amount: Int)] {
        let totalShares = holdings.reduce(0) { $0 + $1.shares }
        guard totalShares > 0 else {
            return []
        }

        var portions = holdings.map { (playerID: $0.playerID, amount: amount * $0.shares / totalShares) }
        let remainders = holdings.enumerated()
            .map { (index: $0.offset, remainder: amount * $0.element.shares % totalShares) }
            .sorted { $0.remainder != $1.remainder ? $0.remainder > $1.remainder : $0.index < $1.index }
        var leftover = amount - portions.reduce(0) { $0 + $1.amount }
        for entry in remainders where leftover > 0 {
            portions[entry.index].amount += 1
            leftover -= 1
        }
        return portions
    }

    static func reindexPropertyIDs(in state: inout GameState) {
        for index in state.players.indices {
            let playerID = state.players[index].id
            state.players[index].propertyIDs = state.properties
                .filter { $0.shares(of: playerID) > 0 }
                .map(\.id)
        }
    }

    static func credit(_ amount: Int, to playerID: UUID, in state: inout GameState) {
        guard let index = state.players.firstIndex(where: { $0.id == playerID }) else {
            return
        }
        state.players[index].balance += amount
    }

    /// Charges a cost to every shareholder by stake; fails without charging anyone if
    /// any of them cannot cover their portion.
    private static func chargeShareholders(_ amount: Int, of property: Property, in state: inout GameState) throws {
        let portions = split(amount, among: property.ownership)
        for portion in portions {
            guard let player = state.players.first(where: { $0.id == portion.playerID }) else {
                throw GameRuleError.playerNotFound(portion.playerID)
            }
            guard player.balance >= portion.amount else {
                throw GameRuleError.insufficientFunds(
                    playerID: portion.playerID,
                    required: portion.amount,
                    available: player.balance
                )
            }
        }
        for portion in portions {
            credit(-portion.amount, to: portion.playerID, in: &state)
        }
    }

    private static func payShareholders(_ amount: Int, of property: Property, in state: inout GameState) {
        for portion in split(amount, among: property.ownership) {
            credit(portion.amount, to: portion.playerID, in: &state)
        }
    }
}
