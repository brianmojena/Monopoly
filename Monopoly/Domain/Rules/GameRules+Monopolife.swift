import Foundation

/// Something that happened in the game that a role may like or dislike
/// (MONOPOLIFE_RULES section 3.3). The money rules emit these after they succeed.
enum LifeTrigger: Equatable {
    case rentPaid(payerID: UUID, amount: Int, colorGroup: ColorGroup, level: Int)
    /// `amount` is what the player keeps before any loan cut.
    case rentReceived(playerID: UUID, payerID: UUID, amount: Int)
    case propertyBought(playerID: UUID)
    /// Money paid for something: a property, a level, rent, a trip or a Life Card.
    /// Negative when selling a level gives some back.
    case moneySpent(playerID: UUID, amount: Int)
    /// `paid` is what the player paid, their own part plus any part they covered.
    case leveledUp(playerID: UUID, managesProperty: Bool, paid: Int)
    case mortgaged(playerID: UUID)
    case loanTaken(playerID: UUID)
    case salaryCollected(playerID: UUID, hadCardDebt: Bool)
    case travelPaid(playerID: UUID)
    case dealSettled(participantIDs: Set<UUID>, isScorable: Bool)
    case auctionWon(winnerID: UUID, bidderIDs: Set<UUID>)
    case jailed(playerID: UUID)
    case wentBankrupt(playerID: UUID)
    case moneyGiven(playerID: UUID, recipientID: UUID, amount: Int)
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
                bag = LifeRole.playable.shuffled(using: &generator)
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
        var profiles: [UUID: LifeProfile] = [:]
        // In player order, so the same seed always gives the same disguises.
        for playerID in playerIDs {
            guard let role = roles[playerID] else { continue }
            var profile = LifeProfile(role: role)
            if role == .chameleon {
                profile.disguise = LifeRole.chameleonDisguises.randomElement(using: &generator)
            }
            profiles[playerID] = profile
        }
        for (playerID, rivalID) in assignRivals(to: playerIDs) {
            profiles[playerID]?.rivalTargetID = rivalID
        }
        return MonopolifeState(
            roundLimit: roundLimit,
            profiles: profiles,
            lifeDeck: shuffledLifeDeck(using: &generator),
            randomState: generator.next()
        )
    }

    /// Pairs each player with the one sitting opposite them in turn order (with 4 players,
    /// 1 with 3 and 2 with 4), so rivals are each other's rival. With an odd number of
    /// players the last one is left unpaired and gets the first player as a one-way rival.
    static func assignRivals(to playerIDs: [UUID]) -> [UUID: UUID] {
        guard playerIDs.count > 1 else {
            return [:]
        }
        let half = playerIDs.count / 2
        var rivals: [UUID: UUID] = [:]
        for index in 0..<half {
            rivals[playerIDs[index]] = playerIDs[index + half]
            rivals[playerIDs[index + half]] = playerIDs[index]
        }
        if playerIDs.count.isMultiple(of: 2) == false, let last = playerIDs.last {
            rivals[last] = playerIDs[0]
        }
        return rivals
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
        guard let activeRole = state.monopolife?.profiles[playerID]?.activeRole,
              effect.role == nil || effect.role == activeRole else {
            return
        }
        adjustHappiness(of: playerID, by: delta, reason: .role(effect), in: &state)
    }

    /// Applies a rivalry like to every player whose rival is `targetID`.
    private static func applyRivalEffect(
        _ effect: LifeRoleEffect,
        _ delta: Int,
        whenTargetIs targetID: UUID,
        in state: inout GameState
    ) {
        let rivalIDs = (state.monopolife?.profiles ?? [:])
            .filter { $0.value.rivalTargetID == targetID }
            .keys
        for rivalID in rivalIDs {
            applyRoleEffect(effect, delta, to: rivalID, in: &state)
        }
    }

    static func applyLifeTrigger(_ trigger: LifeTrigger, in state: inout GameState) {
        guard state.monopolife != nil else {
            return
        }

        switch trigger {
        case let .rentPaid(payerID, _, colorGroup, level):
            if let role = state.monopolife?.profiles[payerID]?.activeRole {
                let points = LifeRoleValues.rentVisitPoints(for: role, boardSide: colorGroup.boardSide, level: level)
                adjustHappiness(of: payerID, by: points, reason: .rentVisit, in: &state)
            }
            recordInteraction(of: payerID, in: &state)
            stampPassport(of: payerID, in: colorGroup, in: &state)
        case let .rentReceived(playerID, payerID, amount):
            if state.monopolife?.profiles[playerID]?.activeRole == .entrepreneur,
               let scored = state.monopolife?.profiles[playerID]?.rentPointsThisRound {
                let points = min(amount / LifeRoleValues.entrepreneurRentStep, LifeRoleValues.entrepreneurRentPointsCap - scored)
                if points > 0 {
                    state.monopolife?.profiles[playerID]?.rentPointsThisRound = scored + points
                    applyRoleEffect(.entrepreneurRentReceived, points, to: playerID, in: &state)
                }
            }
            recordInteraction(of: playerID, in: &state)
            if state.monopolife?.profiles[playerID]?.rivalTargetID == payerID {
                applyRoleEffect(.rivalRentFromTarget, LifeRoleValues.rivalRentFromTarget, to: playerID, in: &state)
            }
        case let .propertyBought(playerID):
            let heldProperties = state.properties.filter { $0.shares(of: playerID) > 0 }.count
            if heldProperties > LifeRoleValues.globetrotterPropertiesWithoutRoots {
                applyRoleEffect(.globetrotterPropertyBought, LifeRoleValues.globetrotterPropertyBought, to: playerID, in: &state)
            }
        case let .moneySpent(playerID, amount):
            if let spent = state.monopolife?.profiles[playerID]?.moneySpent {
                state.monopolife?.profiles[playerID]?.moneySpent = max(0, spent + amount)
            }
        case let .leveledUp(playerID, managesProperty, paid):
            if managesProperty {
                let points = max(1, paid / LifeRoleValues.entrepreneurLevelUpStep)
                applyRoleEffect(.entrepreneurLevelUp, points, to: playerID, in: &state)
            }
        case let .mortgaged(playerID):
            applyRoleEffect(.entrepreneurMortgage, LifeRoleValues.entrepreneurMortgage, to: playerID, in: &state)
            applyRivalEffect(.rivalTargetSetback, LifeRoleValues.rivalTargetSetback, whenTargetIs: playerID, in: &state)
        case let .loanTaken(playerID):
            applyRoleEffect(.saverLoan, LifeRoleValues.saverLoan, to: playerID, in: &state)
        case let .salaryCollected(playerID, hadCardDebt):
            applyRoleEffect(.globetrotterSalary, LifeRoleValues.globetrotterSalary, to: playerID, in: &state)
            if !hadCardDebt {
                applyRoleEffect(.saverSalaryWithoutDebt, LifeRoleValues.saverSalaryWithoutDebt, to: playerID, in: &state)
            }
        case let .travelPaid(playerID):
            applyRoleEffect(.globetrotterTrip, LifeRoleValues.globetrotterTrip, to: playerID, in: &state)
        case let .dealSettled(participantIDs, isScorable):
            guard isScorable else {
                return
            }
            for playerID in participantIDs {
                recordInteraction(of: playerID, in: &state)
            }
        case let .auctionWon(winnerID, bidderIDs):
            if let targetID = state.monopolife?.profiles[winnerID]?.rivalTargetID, bidderIDs.contains(targetID) {
                applyRoleEffect(.rivalAuctionWon, LifeRoleValues.rivalAuctionWon, to: winnerID, in: &state)
            }
        case let .jailed(playerID):
            adjustHappiness(of: playerID, by: LifeRoleValues.jailed, reason: .jail, in: &state)
            applyRivalEffect(.rivalTargetSetback, LifeRoleValues.rivalTargetSetback, whenTargetIs: playerID, in: &state)
        case let .wentBankrupt(playerID):
            applyRivalEffect(.rivalTargetBankrupt, LifeRoleValues.rivalTargetBankrupt, whenTargetIs: playerID, in: &state)
        case let .moneyGiven(playerID, recipientID, amount):
            guard amount >= LifeRoleValues.socialMinimumGift else {
                return
            }
            recordInteraction(of: playerID, in: &state)
            recordInteraction(of: recipientID, in: &state)
        }
    }

    /// The Globetrotter's first rent in each color group is a new stamp; later ones
    /// are a revisit.
    private static func stampPassport(of playerID: UUID, in colorGroup: ColorGroup, in state: inout GameState) {
        guard state.monopolife?.profiles[playerID]?.activeRole == .globetrotter else {
            return
        }
        guard state.monopolife?.profiles[playerID]?.rentStamps.contains(colorGroup) == false else {
            applyRoleEffect(.globetrotterRevisit, LifeRoleValues.globetrotterRevisit, to: playerID, in: &state)
            return
        }
        state.monopolife?.profiles[playerID]?.rentStamps.insert(colorGroup)
        applyRoleEffect(.globetrotterStamp, LifeRoleValues.globetrotterStamp, to: playerID, in: &state)
        if state.monopolife?.profiles[playerID]?.rentStamps.count == ColorGroup.allCases.count {
            applyRoleEffect(.globetrotterAllStamps, LifeRoleValues.globetrotterAllStamps, to: playerID, in: &state)
        }
    }

    /// Money that moves between the player and another one: rent, a deal or a gift.
    /// The Social scores the first few each round.
    private static func recordInteraction(of playerID: UUID, in state: inout GameState) {
        guard let count = state.monopolife?.profiles[playerID]?.interactionsThisRound else {
            return
        }
        state.monopolife?.profiles[playerID]?.interactionsThisRound = count + 1
        if count < LifeRoleValues.socialScoredInteractionsPerRound {
            applyRoleEffect(.socialInteraction, LifeRoleValues.socialInteraction, to: playerID, in: &state)
        }
    }

    /// Whether a settled deal counts as an interaction for the Social: it must move at
    /// least a minimum amount of money or at least one share.
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
        return money >= LifeRoleValues.socialMinimumGift
    }

    // MARK: Rounds and the end of the game

    /// Applies the likes checked when a player ends their own turn.
    static func endOfTurn(of playerID: UUID, in state: inout GameState) {
        guard let profile = state.monopolife?.profiles[playerID],
              let player = state.players.first(where: { $0.id == playerID }) else {
            return
        }
        switch profile.activeRole {
        case .saver:
            let points = min(player.balance / LifeRoleValues.saverCashStep, LifeRoleValues.saverSavingsPointsCap)
            applyRoleEffect(.saverSavings, points, to: playerID, in: &state)
        case .consumer:
            let points = min(profile.moneySpent / LifeRoleValues.consumerSpendingStep, LifeRoleValues.consumerSpendingPointsCap)
            applyRoleEffect(.consumerSpending, points, to: playerID, in: &state)
        case .entrepreneur, .social, .globetrotter, .chameleon:
            break
        }
        state.monopolife?.profiles[playerID]?.moneySpent = 0
    }

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

            switch profile.activeRole {
            case .consumer:
                if player.balance > LifeRoleValues.consumerHoardingThreshold {
                    applyRoleEffect(.consumerHoardedCash, LifeRoleValues.consumerHoarding, to: player.id, in: &state)
                }
            case .social:
                if profile.interactionsThisRound == 0, state.round >= LifeRoleValues.socialLonelyFromRound {
                    applyRoleEffect(.socialLonely, LifeRoleValues.socialLonely, to: player.id, in: &state)
                }
            case .entrepreneur, .saver, .globetrotter, .chameleon:
                break
            }

            if let rivalID = profile.rivalTargetID {
                let netWorth = netWorthOrBalance(of: player.id, in: state)
                let rivalNetWorth = netWorthOrBalance(of: rivalID, in: state)
                if netWorth > rivalNetWorth {
                    applyRoleEffect(.rivalAhead, LifeRoleValues.rivalAhead, to: player.id, in: &state)
                } else if netWorth < rivalNetWorth {
                    applyRoleEffect(.rivalBehind, LifeRoleValues.rivalBehind, to: player.id, in: &state)
                }
            }
        }

        let roundLimit = monopolife.roundLimit
        if state.round % LifeRoleValues.chameleonDisguiseRounds == 0, state.round < roundLimit {
            for (playerID, profile) in monopolife.profiles where profile.role == .chameleon {
                changeDisguise(of: playerID, in: &state)
            }
        }

        for playerID in monopolife.profiles.keys {
            state.monopolife?.profiles[playerID]?.interactionsThisRound = 0
            state.monopolife?.profiles[playerID]?.rentPointsThisRound = 0
        }
    }

    /// Gives the Chameleon a different role's likes, drawn from the game's seed.
    static func changeDisguise(of playerID: UUID, in state: inout GameState) {
        guard let monopolife = state.monopolife,
              let profile = monopolife.profiles[playerID], profile.role == .chameleon else {
            return
        }
        var generator = SeededRandom(state: monopolife.randomState)
        let options = LifeRole.chameleonDisguises.filter { $0 != profile.disguise }
        guard let disguise = options.randomElement(using: &generator) else {
            return
        }
        state.monopolife?.randomState = generator.state
        state.monopolife?.profiles[playerID]?.disguise = disguise
        adjustHappiness(of: playerID, by: LifeRoleValues.chameleonNewDisguise, reason: .newDisguise(disguise), in: &state)
    }

    static func requireGameNotFinished(in state: GameState) throws {
        if state.isFinished {
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
        applyLifeTrigger(.wentBankrupt(playerID: playerID), in: &state)
    }

    // MARK: Life Cards

    /// A player asks for a Life Card; the host then deals it with `dealLifeCard`,
    /// choosing a random one or one that's good for them (MONOPOLIFE_RULES section 5).
    static func requestLifeCard(in state: GameState, playerID: UUID) throws -> GameState {
        try requireCanDrawLifeCard(in: state, playerID: playerID)
        var updatedState = state
        updatedState.monopolife?.lifeCardRequest = playerID
        return updatedState
    }

    /// The host deals the requested Life Card.
    static func dealLifeCard<Generator: RandomNumberGenerator>(
        in state: GameState,
        favorable: Bool,
        using generator: inout Generator
    ) throws -> GameState {
        guard let playerID = state.monopolife?.lifeCardRequest else {
            throw GameRuleError.noLifeCardRequest
        }
        var updatedState = state
        updatedState.monopolife?.lifeCardRequest = nil
        return try drawLifeCard(in: updatedState, playerID: playerID, favorable: favorable, using: &generator)
    }

    private static func requireCanDrawLifeCard(in state: GameState, playerID: UUID) throws {
        guard let monopolife = state.monopolife, monopolife.profiles[playerID] != nil else {
            throw GameRuleError.monopolifeOnly
        }
        try requireActivePlayer(in: state, playerID: playerID)
        try requireTurn(in: state, playerID: playerID)
        guard monopolife.pendingLifeCard == nil else {
            throw GameRuleError.lifeCardDecisionPending
        }
        guard monopolife.lifeCardRequest == nil else {
            throw GameRuleError.lifeCardRequestPending
        }
    }

    /// Whether a card would make this player happier, by their current role.
    static func isFavorable(_ card: LifeCard, for profile: LifeProfile) -> Bool {
        card.happiness(for: profile.activeRole) > 0
    }

    /// Draws the next card of the deck, or with `favorable` a random one that is good
    /// for the player: from what's left in the deck, or from the whole deck when none
    /// is left there, which then isn't touched.
    static func drawLifeCard<Generator: RandomNumberGenerator>(
        in state: GameState,
        playerID: UUID,
        favorable: Bool = false,
        using generator: inout Generator
    ) throws -> GameState {
        try requireCanDrawLifeCard(in: state, playerID: playerID)
        guard let monopolife = state.monopolife, let profile = monopolife.profiles[playerID] else {
            throw GameRuleError.monopolifeOnly
        }

        var updatedState = state
        if monopolife.lifeDeck.isEmpty {
            updatedState.monopolife?.lifeDeck = shuffledLifeDeck(using: &generator)
        }
        let deck = updatedState.monopolife?.lifeDeck ?? []
        let card: LifeCard
        if favorable {
            let goodInDeck = deck.indices.filter { index in
                LifeCards.card(withID: deck[index]).map { isFavorable($0, for: profile) } ?? false
            }
            if let index = goodInDeck.randomElement(using: &generator), let found = LifeCards.card(withID: deck[index]) {
                card = found
                updatedState.monopolife?.lifeDeck.remove(at: index)
            } else if let found = LifeCards.all.filter({ isFavorable($0, for: profile) }).randomElement(using: &generator) {
                card = found
            } else {
                throw GameRuleError.monopolifeOnly
            }
        } else {
            guard let cardID = deck.first, let found = LifeCards.card(withID: cardID) else {
                throw GameRuleError.monopolifeOnly
            }
            card = found
            updatedState.monopolife?.lifeDeck.removeFirst()
        }

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
        applyLifeTrigger(.moneySpent(playerID: playerID, amount: card.cost), in: &updatedState)
        if let possession = card.grantedPossession {
            updatedState.monopolife?.profiles[playerID]?.possessions.insert(possession)
        }
        return updatedState
    }

    static func requireNoPendingLifeCard(in state: GameState, playerID: UUID) throws {
        if state.monopolife?.pendingLifeCard?.playerID == playerID {
            throw GameRuleError.lifeCardDecisionPending
        }
        if state.monopolife?.lifeCardRequest == playerID {
            throw GameRuleError.lifeCardRequestPending
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
            let paid = payUpTo(amount, from: playerID, in: &state)
            depositInFreeParking(paid, in: &state)
        case let .collectPerOwnedProperty(each, maximum):
            let owned = state.properties.filter { $0.shares(of: playerID) > 0 }.count
            credit(min(owned * each, maximum), to: playerID, in: &state)
        case let .collectFromEachOtherPlayer(amount):
            for other in state.players where other.id != playerID && other.status == .active {
                let paid = payUpTo(amount, from: other.id, in: &state)
                credit(paid, to: playerID, in: &state)
            }
        }

        if let role = state.monopolife?.profiles[playerID]?.activeRole {
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
