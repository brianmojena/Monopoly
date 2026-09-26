import Foundation

// Board events (GAME_RULES section 8.3): at the end of every few rounds something
// happens on the board. Draws use the seed stored in the state, so the rules stay
// pure and every device agrees on the result the host broadcasts.
extension GameRules {
    /// The rent after the board events and host cards affecting `property`:
    /// percentages first, then flat amounts, never below 0.
    static func applyingRentEffects(to rent: Int, of property: Property, in state: GameState) -> Int {
        let effects = rentEffects(on: property.id, in: state)
        guard !effects.isEmpty else {
            return rent
        }
        let percent = effects.reduce(0) { $0 + $1.percent }
        let flat = effects.reduce(0) { $0 + $1.flat }
        return max(0, rent * max(0, 100 + percent) / 100 + flat)
    }

    /// Every rent change on `propertyID`, from board events and host cards.
    static func rentEffects(on propertyID: UUID, in state: GameState) -> [ActiveRentEffect] {
        ((state.boardEvents?.rentEffects ?? []) + state.hostCardRentEffects)
            .filter { $0.propertyIDs.contains(propertyID) }
    }

    /// Called when `round` has just ended: drops expired rent effects, then, when the
    /// scheduled round has come, draws and applies an event and schedules the next one.
    static func runBoardEvents(afterRound round: Int, in state: inout GameState) {
        guard let boardEvents = state.boardEvents else {
            return
        }
        state.boardEvents?.rentEffects.removeAll { effect in
            effect.lastRound.map { $0 <= round } ?? false
        }
        guard boardEvents.isEventDue(afterRound: round) else {
            return
        }

        var generator = SeededRandom(state: boardEvents.randomState)
        let candidates = BoardEventCatalog.all.filter { !targets(for: $0, in: state).isEmpty }
        if let event = candidates.randomElement(using: &generator),
           let target = targets(for: event, in: state).randomElement(using: &generator) {
            happen(event, on: target, afterRound: round, in: &state)
        }
        state.boardEvents?.randomState = generator.state
        state.boardEvents?.scheduleNextEvent(afterRound: round)
    }

    /// Every place `event` could land right now.
    static func targets(for event: BoardEvent, in state: GameState) -> [BoardEventTarget] {
        switch event.targetKind {
        case .side:
            return Array(Set(state.properties.map(\.colorGroup.boardSide))).sorted().map { .side($0) }
        case .colorGroup:
            return ColorGroup.allCases.filter { group in state.properties.contains { $0.colorGroup == group } }.map { .colorGroup($0) }
        case .ownedProperty:
            return state.properties.filter(\.isOwned).map { .property($0.id) }
        case .leveledProperty:
            return state.properties.filter { $0.isOwned && $0.constructionLevel > 0 }.map { .property($0.id) }
        case .wholeBoard:
            return state.properties.isEmpty ? [] : [.wholeBoard]
        case .allPlayers:
            return [.allPlayers]
        }
    }

    static func propertyIDs(for target: BoardEventTarget, in state: GameState) -> [UUID] {
        switch target {
        case let .side(side):
            return state.properties.filter { $0.colorGroup.boardSide == side }.map(\.id)
        case let .colorGroup(group):
            return state.properties.filter { $0.colorGroup == group }.map(\.id)
        case let .property(propertyID):
            return state.properties.contains { $0.id == propertyID } ? [propertyID] : []
        case .wholeBoard:
            return state.properties.map(\.id)
        case .allPlayers:
            return []
        }
    }

    /// Applies `event` on `target` and records it so every device announces it.
    static func happen(_ event: BoardEvent, on target: BoardEventTarget, afterRound round: Int, in state: inout GameState) {
        guard state.boardEvents != nil else {
            return
        }
        let affectedIDs = propertyIDs(for: target, in: state)

        switch event.effect {
        case let .rent(flat, percent, rounds):
            state.boardEvents?.rentEffects.append(ActiveRentEffect(
                eventID: event.id,
                propertyIDs: Set(affectedIDs),
                flat: flat,
                percent: percent,
                lastRound: rounds.map { round + $0 }
            ))
        case let .chargeShareholders(perProperty):
            var collected = 0
            var payerIDs: [UUID] = []
            for property in state.properties where affectedIDs.contains(property.id) && property.isOwned {
                for portion in split(perProperty, among: property.ownership) {
                    let paid = payUpToBank(portion.amount, from: portion.playerID, in: &state)
                    collected += paid
                    if paid > 0, !payerIDs.contains(portion.playerID) {
                        payerIDs.append(portion.playerID)
                    }
                }
            }
            depositInFreeParking(collected, in: &state)
            if event.countsAsTax {
                for playerID in payerIDs {
                    applyLifeTrigger(.taxPaid(playerID: playerID), in: &state)
                }
            }
        case let .payEveryPlayer(amount):
            for player in state.players where player.status == .active {
                credit(amount, to: player.id, in: &state)
            }
        case .levelDown:
            for index in state.properties.indices where affectedIDs.contains(state.properties[index].id) {
                state.properties[index].constructionLevel = max(0, state.properties[index].constructionLevel - 1)
            }
        }

        let sequence = (state.boardEvents?.lastOccurrence?.sequence ?? 0) + 1
        state.boardEvents?.history.append(BoardEventOccurrence(
            sequence: sequence,
            eventID: event.id,
            round: round,
            target: target,
            propertyIDs: affectedIDs
        ))
    }

    /// Board events never cause bankruptcy: a player short of cash pays what they have.
    private static func payUpToBank(_ amount: Int, from playerID: UUID, in state: inout GameState) -> Int {
        guard let index = state.players.firstIndex(where: { $0.id == playerID }) else {
            return 0
        }
        let paid = min(amount, state.players[index].balance)
        state.players[index].balance -= paid
        return paid
    }
}
