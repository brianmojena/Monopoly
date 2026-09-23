import Foundation

/// Something that happened in the game that a role may like or dislike
/// (MONOPOLIFE_RULES section 3.3). The money rules emit these after they succeed.
enum LifeTrigger: Equatable {
    case rentPaid(payerID: UUID, amount: Int, colorGroup: ColorGroup)
    case rentReceived(playerID: UUID)
    case investmentPayout(investorID: UUID)
    case propertyBought(playerID: UUID)
    case leveledUp(playerID: UUID)
    case mortgaged(playerID: UUID)
    case taxPaid(playerID: UUID)
    case loanTaken(playerID: UUID)
    case salaryCollected(playerID: UUID, hadCardDebt: Bool)
    case dealSettled(participantIDs: Set<UUID>, isScorable: Bool)
    case investmentCreated(investorID: UUID)
}

// Monopolife: the winner is whoever has the most happiness when the last round ends
// (MONOPOLIFE_RULES.md). Everything here is a no-op in Classic games.
extension GameRules {
    // MARK: Setup

    /// Deals roles without repeating any until all have been used, then starts over.
    static func assignRoles<Generator: RandomNumberGenerator>(
        to playerIDs: [UUID],
        using generator: inout Generator
    ) -> [UUID: LifeRole] {
        var roles: [UUID: LifeRole] = [:]
        var bag: [LifeRole] = []
        for playerID in playerIDs {
            if bag.isEmpty {
                bag = LifeRole.allCases.shuffled(using: &generator)
            }
            roles[playerID] = bag.removeLast()
        }
        return roles
    }

    static func makeMonopolifeState<Generator: RandomNumberGenerator>(
        playerIDs: [UUID],
        roundLimit: Int,
        using generator: inout Generator
    ) -> MonopolifeState {
        let roles = assignRoles(to: playerIDs, using: &generator)
        return MonopolifeState(
            roundLimit: roundLimit,
            profiles: roles.mapValues { LifeProfile(role: $0) },
            lifeDeck: shuffledLifeDeck(using: &generator)
        )
    }

    static func shuffledLifeDeck<Generator: RandomNumberGenerator>(using generator: inout Generator) -> [String] {
        LifeCards.all.map(\.id).shuffled(using: &generator)
    }

    static func acknowledgeRole(in state: GameState, playerID: UUID) throws -> GameState {
        guard state.monopolife?.profiles[playerID] != nil else {
            throw GameRuleError.monopolifeOnly
        }
        var updatedState = state
        updatedState.monopolife?.profiles[playerID]?.hasAcknowledgedRole = true
        return updatedState
    }

    // MARK: Happiness

    /// The only way happiness changes. It never drops below 0, and the log records the
    /// change actually applied.
    static func adjustHappiness(
        of playerID: UUID,
        by delta: Int,
        reason: HappinessReason,
        in state: inout GameState
    ) {
        guard delta != 0, let profile = state.monopolife?.profiles[playerID] else {
            return
        }
        let newHappiness = max(0, profile.happiness + delta)
        let appliedDelta = newHappiness - profile.happiness
        guard appliedDelta != 0 else {
            return
        }
        state.monopolife?.profiles[playerID]?.happiness = newHappiness
        state.monopolife?.happinessLog.append(HappinessEvent(
            playerID: playerID,
            delta: appliedDelta,
            reason: reason,
            round: state.round
        ))
    }

    private static func applyRoleEffect(
        _ effect: LifeRoleEffect,
        _ delta: Int,
        to playerID: UUID,
        in state: inout GameState
    ) {
        guard state.monopolife?.profiles[playerID]?.role == effect.role else {
            return
        }
        adjustHappiness(of: playerID, by: delta, reason: .role(effect), in: &state)
    }

    static func applyLifeTrigger(_ trigger: LifeTrigger, in state: inout GameState) {
        guard state.monopolife != nil else {
            return
        }

        switch trigger {
        case let .rentPaid(payerID, amount, colorGroup):
            let consumerPoints = min(amount / LifeRoleValues.consumerRentStep, LifeRoleValues.consumerRentPointsCap)
            applyRoleEffect(.consumerRentPaid, consumerPoints, to: payerID, in: &state)

            guard state.monopolife?.profiles[payerID]?.role == .globetrotter,
                  state.monopolife?.profiles[payerID]?.rentStamps.contains(colorGroup) == false else {
                return
            }
            state.monopolife?.profiles[payerID]?.rentStamps.insert(colorGroup)
            applyRoleEffect(.globetrotterStamp, LifeRoleValues.globetrotterStamp, to: payerID, in: &state)
            if state.monopolife?.profiles[payerID]?.rentStamps.count == ColorGroup.allCases.count {
                applyRoleEffect(.globetrotterAllStamps, LifeRoleValues.globetrotterAllStamps, to: payerID, in: &state)
            }
        case let .rentReceived(playerID):
            applyRoleEffect(.entrepreneurRentReceived, LifeRoleValues.entrepreneurRentReceived, to: playerID, in: &state)
        case let .investmentPayout(investorID):
            applyRoleEffect(.investorPayout, LifeRoleValues.investorPayout, to: investorID, in: &state)
        case let .propertyBought(playerID):
            applyRoleEffect(.globetrotterPropertyBought, LifeRoleValues.globetrotterPropertyBought, to: playerID, in: &state)
        case let .leveledUp(playerID):
            applyRoleEffect(.consumerLevelUp, LifeRoleValues.consumerLevelUp, to: playerID, in: &state)
        case let .mortgaged(playerID):
            applyRoleEffect(.entrepreneurMortgage, LifeRoleValues.entrepreneurMortgage, to: playerID, in: &state)
        case let .taxPaid(playerID):
            applyRoleEffect(.investorTax, LifeRoleValues.investorTax, to: playerID, in: &state)
        case let .loanTaken(playerID):
            applyRoleEffect(.saverLoan, LifeRoleValues.saverLoan, to: playerID, in: &state)
        case let .salaryCollected(playerID, hadCardDebt):
            applyRoleEffect(.globetrotterSalary, LifeRoleValues.globetrotterSalary, to: playerID, in: &state)
            if !hadCardDebt {
                applyRoleEffect(.saverSalaryWithoutDebt, LifeRoleValues.saverSalaryWithoutDebt, to: playerID, in: &state)
            }
        case let .dealSettled(participantIDs, isScorable):
            for playerID in participantIDs where state.monopolife?.profiles[playerID] != nil {
                state.monopolife?.profiles[playerID]?.tookPartInDealThisRound = true
                guard isScorable,
                      let scored = state.monopolife?.profiles[playerID]?.scoredDealsThisRound,
                      scored < LifeRoleValues.socialScoredDealsPerRound,
                      state.monopolife?.profiles[playerID]?.role == .social else {
                    continue
                }
                state.monopolife?.profiles[playerID]?.scoredDealsThisRound = scored + 1
                applyRoleEffect(.socialDeal, LifeRoleValues.socialDeal, to: playerID, in: &state)
            }
        case let .investmentCreated(investorID):
            applyRoleEffect(.investorInvestmentCreated, LifeRoleValues.investorInvestmentCreated, to: investorID, in: &state)
        }
    }

    /// Whether a settled deal counts for the Social role: it must move at least a
    /// minimum amount of money or at least one share.
    static func isScorableDeal(_ deal: MarketDeal) -> Bool {
        if deal.sharedPurchase != nil {
            return true
        }
        var money = 0
        for transfer in deal.transfers {
            switch transfer.asset {
            case let .money(amount):
                money += amount
            case .shares:
                return true
            }
        }
        return money >= LifeRoleValues.socialMinimumDealMoney
    }

    // MARK: Rounds and the end of the game

    /// Applies every role's end-of-round likes and dislikes, then resets the per-round
    /// counters.
    static func endOfRound(in state: inout GameState) {
        guard let monopolife = state.monopolife else {
            return
        }

        for player in state.players where player.status == .active {
            guard let profile = monopolife.profiles[player.id] else {
                continue
            }
            let heldProperties = state.properties.filter { $0.shares(of: player.id) > 0 }

            switch profile.role {
            case .consumer:
                if player.balance > LifeRoleValues.consumerHoardingThreshold {
                    applyRoleEffect(.consumerHoardedCash, LifeRoleValues.consumerHoarding, to: player.id, in: &state)
                }
            case .entrepreneur:
                let points = min(
                    heldProperties.count * LifeRoleValues.entrepreneurPointsPerProperty,
                    LifeRoleValues.entrepreneurPropertyPointsCap
                )
                applyRoleEffect(.entrepreneurOwnedProperties, points, to: player.id, in: &state)
            case .saver:
                let points = min(player.balance / LifeRoleValues.saverCashStep, LifeRoleValues.saverSavingsPointsCap)
                applyRoleEffect(.saverSavings, points, to: player.id, in: &state)
            case .social:
                if !profile.tookPartInDealThisRound {
                    applyRoleEffect(.socialNoDeals, LifeRoleValues.socialNoDeals, to: player.id, in: &state)
                }
            case .investor:
                let colorGroups = Set(heldProperties.map(\.colorGroup))
                let points = min(
                    colorGroups.count * LifeRoleValues.investorPointsPerColorGroup,
                    LifeRoleValues.investorDiversificationPointsCap
                )
                applyRoleEffect(.investorDiversification, points, to: player.id, in: &state)
            case .globetrotter:
                break
            }
        }

        for playerID in monopolife.profiles.keys {
            state.monopolife?.profiles[playerID]?.scoredDealsThisRound = 0
            state.monopolife?.profiles[playerID]?.tookPartInDealThisRound = false
        }
    }

    static func requireGameNotFinished(in state: GameState) throws {
        if state.monopolife?.isFinished == true {
            throw GameRuleError.gameFinished
        }
    }

    /// Most happiness wins; a tie goes to the higher net worth, and a tie on both is
    /// shared.
    static func winners(in state: GameState) -> [UUID] {
        guard let monopolife = state.monopolife else {
            return []
        }
        let scores = state.players.compactMap { player -> (id: UUID, happiness: Int, netWorth: Int)? in
            guard let profile = monopolife.profiles[player.id] else {
                return nil
            }
            let netWorth = (try? GameRules.netWorth(of: player.id, in: state)) ?? player.balance
            return (player.id, profile.happiness, netWorth)
        }
        guard let best = scores.max(by: { ($0.happiness, $0.netWorth) < ($1.happiness, $1.netWorth) }) else {
            return []
        }
        return scores
            .filter { $0.happiness == best.happiness && $0.netWorth == best.netWorth }
            .map(\.id)
    }

    // MARK: Bankruptcy

    /// In Monopolife a bankrupt player is not eliminated: they keep half their
    /// happiness (rounded down) and get a rescue balance from the bank.
    static func rescueFromBankruptcy(_ playerID: UUID, in state: inout GameState) {
        guard let index = state.players.firstIndex(where: { $0.id == playerID }),
              let happiness = state.monopolife?.profiles[playerID]?.happiness else {
            return
        }
        state.players[index].status = .active
        state.players[index].balance = LifeRoleValues.bankruptcyRescueBalance
        adjustHappiness(of: playerID, by: happiness / 2 - happiness, reason: .bankruptcy, in: &state)
    }

    // MARK: Life Cards

    static func drawLifeCard<Generator: RandomNumberGenerator>(
        in state: GameState,
        playerID: UUID,
        using generator: inout Generator
    ) throws -> GameState {
        guard let monopolife = state.monopolife, monopolife.profiles[playerID] != nil else {
            throw GameRuleError.monopolifeOnly
        }
        try requireActivePlayer(in: state, playerID: playerID)
        try requireTurn(in: state, playerID: playerID)
        guard monopolife.pendingLifeCard == nil else {
            throw GameRuleError.lifeCardDecisionPending
        }

        var updatedState = state
        if monopolife.lifeDeck.isEmpty {
            updatedState.monopolife?.lifeDeck = shuffledLifeDeck(using: &generator)
        }
        guard let cardID = updatedState.monopolife?.lifeDeck.first,
              let card = LifeCards.card(withID: cardID) else {
            throw GameRuleError.monopolifeOnly
        }
        updatedState.monopolife?.lifeDeck.removeFirst()

        let sequence = (monopolife.lastLifeCardDraw?.sequence ?? 0) + 1
        var hadEffect = true
        switch card.kind {
        case .decision:
            let draw = LifeCardDraw(playerID: playerID, cardID: card.id, sequence: sequence, hadEffect: true)
            updatedState.monopolife?.pendingLifeCard = draw
            updatedState.monopolife?.lastLifeCardDraw = draw
            return updatedState
        case .possession:
            guard let required = card.requiredPossession,
                  monopolife.profiles[playerID]?.possessions.contains(required) == true else {
                hadEffect = false
                break
            }
            applyLifeCardEffect(card, to: playerID, in: &updatedState)
            if card.removesRequiredPossession {
                updatedState.monopolife?.profiles[playerID]?.possessions.remove(required)
            }
        case .event, .movement:
            applyLifeCardEffect(card, to: playerID, in: &updatedState)
        }

        updatedState.monopolife?.lastLifeCardDraw = LifeCardDraw(
            playerID: playerID,
            cardID: card.id,
            sequence: sequence,
            hadEffect: hadEffect
        )
        return updatedState
    }

    static func resolveLifeCardDecision(
        in state: GameState,
        playerID: UUID,
        accept: Bool
    ) throws -> GameState {
        guard state.monopolife != nil else {
            throw GameRuleError.monopolifeOnly
        }
        guard let pending = state.monopolife?.pendingLifeCard,
              pending.playerID == playerID,
              let card = LifeCards.card(withID: pending.cardID) else {
            throw GameRuleError.noPendingLifeCard
        }

        var updatedState = state
        updatedState.monopolife?.pendingLifeCard = nil
        guard accept else {
            return updatedState
        }

        guard let player = state.players.first(where: { $0.id == playerID }) else {
            throw GameRuleError.playerNotFound(playerID)
        }
        guard player.balance >= card.cost else {
            throw GameRuleError.insufficientFunds(playerID: playerID, required: card.cost, available: player.balance)
        }
        applyLifeCardEffect(card, to: playerID, in: &updatedState)
        if let possession = card.grantedPossession {
            updatedState.monopolife?.profiles[playerID]?.possessions.insert(possession)
        }
        return updatedState
    }

    static func requireNoPendingLifeCard(in state: GameState, playerID: UUID) throws {
        if state.monopolife?.pendingLifeCard?.playerID == playerID {
            throw GameRuleError.lifeCardDecisionPending
        }
    }

    /// Cards never cause bankruptcy: a player who cannot pay in full pays what they have.
    private static func applyLifeCardEffect(_ card: LifeCard, to playerID: UUID, in state: inout GameState) {
        switch card.money {
        case .none:
            break
        case let .collect(amount):
            credit(amount, to: playerID, in: &state)
        case let .pay(amount):
            payUpTo(amount, from: playerID, in: &state)
        case let .collectPerOwnedProperty(each, maximum):
            let owned = state.properties.filter { $0.shares(of: playerID) > 0 }.count
            credit(min(owned * each, maximum), to: playerID, in: &state)
        case let .collectFromEachOtherPlayer(amount):
            for other in state.players where other.id != playerID && other.status == .active {
                let paid = payUpTo(amount, from: other.id, in: &state)
                credit(paid, to: playerID, in: &state)
            }
        }

        if let role = state.monopolife?.profiles[playerID]?.role {
            adjustHappiness(of: playerID, by: card.happiness(for: role), reason: .lifeCard(card.id), in: &state)
        }
        if card.othersHappiness != 0 {
            for other in state.players where other.id != playerID && other.status == .active {
                adjustHappiness(of: other.id, by: card.othersHappiness, reason: .lifeCard(card.id), in: &state)
            }
        }
    }

    @discardableResult
    private static func payUpTo(_ amount: Int, from playerID: UUID, in state: inout GameState) -> Int {
        guard let index = state.players.firstIndex(where: { $0.id == playerID }) else {
            return 0
        }
        let paid = min(amount, state.players[index].balance)
        state.players[index].balance -= paid
        return paid
    }
}
