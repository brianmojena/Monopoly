import Foundation

// Host cards (GAME_RULES section 8.5): physical cards only the host resolves in the
// app. Their rent changes live in the state even when board events are off.
extension GameRules {
    static func playHostCard(_ play: HostCardPlay, in state: GameState) throws -> GameState {
        var updatedState = state

        switch play.card {
        case .rentDropOnSide, .rentRaiseOnSide, .rentShiftToSide:
            guard let side = play.side, (1...4).contains(side) else {
                throw GameRuleError.invalidBoardSide(play.side ?? 0)
            }
            if let rounds = play.rounds, rounds < 1 {
                throw GameRuleError.invalidAmount(rounds)
            }
            let lastRound = play.rounds.map { state.round + $0 - 1 }
            let changes: [(sides: [Int], flat: Int)]
            switch play.card {
            case .rentDropOnSide:
                changes = [([side], -HostCard.rentChange)]
            case .rentRaiseOnSide:
                changes = [([side], HostCard.rentChange)]
            default:
                changes = [([side], HostCard.rentChange), (BoardEventsState.neighbors(ofSide: side), -HostCard.rentChange)]
            }
            for change in changes {
                let propertyIDs = state.properties.filter { change.sides.contains($0.colorGroup.boardSide) }.map(\.id)
                updatedState.hostCardRentEffects.append(ActiveRentEffect(
                    eventID: play.card.rawValue,
                    propertyIDs: Set(propertyIDs),
                    flat: change.flat,
                    percent: 0,
                    lastRound: lastRound
                ))
            }
        case .advanceAndLevelUp:
            guard let playerID = play.playerID, let propertyID = play.propertyID else {
                throw GameRuleError.incompleteHostCard
            }
            try requireActivePlayer(in: state, playerID: playerID)
            guard let index = state.properties.firstIndex(where: { $0.id == propertyID }) else {
                throw GameRuleError.propertyNotFound(propertyID)
            }
            let property = state.properties[index]
            guard property.isOwned else {
                throw GameRuleError.propertyHasNoOwner(propertyID)
            }
            guard !property.isMortgaged else {
                throw GameRuleError.propertyIsMortgaged(propertyID)
            }
            guard property.constructionLevel < Property.maximumLevel else {
                throw GameRuleError.propertyAtMaximumLevel(propertyID)
            }
            updatedState.properties[index].constructionLevel += 1
        }

        let sequence = (state.lastHostCard?.sequence ?? 0) + 1
        updatedState.lastHostCard = HostCardOccurrence(sequence: sequence, play: play, round: state.round)
        return updatedState
    }

    /// Drops the host card rent changes whose last round was `round`.
    static func expireHostCardEffects(afterRound round: Int, in state: inout GameState) {
        state.hostCardRentEffects.removeAll { effect in
            effect.lastRound.map { $0 <= round } ?? false
        }
    }
}
