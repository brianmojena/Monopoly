import Foundation

/// How a player gets out of jail (GAME_RULES section 5).
enum JailExit: String, Codable, Equatable {
    case doubles
    case payFine
}

// Jail (GAME_RULES section 5): the app tracks who is in jail and for how many turns so
// every device can see it, and charges the fine for getting out.
extension GameRules {
    static let jailFine = 100
    /// Turns served in jail before the player walks out for free.
    static let maximumJailTurns = 3

    static func goToJail(in state: GameState, playerID: UUID) throws -> GameState {
        try requireActivePlayer(in: state, playerID: playerID)
        guard let index = state.players.firstIndex(where: { $0.id == playerID }) else {
            throw GameRuleError.playerNotFound(playerID)
        }
        guard !state.players[index].isInJail else {
            throw GameRuleError.alreadyInJail(playerID)
        }
        var updatedState = state
        updatedState.players[index].jailTurn = 0
        applyLifeTrigger(.jailed(playerID: playerID), in: &updatedState)
        return updatedState
    }

    static func leaveJail(in state: GameState, playerID: UUID, exit: JailExit) throws -> GameState {
        try requireActivePlayer(in: state, playerID: playerID)
        guard let index = state.players.firstIndex(where: { $0.id == playerID }) else {
            throw GameRuleError.playerNotFound(playerID)
        }
        guard state.players[index].isInJail else {
            throw GameRuleError.notInJail(playerID)
        }

        var updatedState = state
        if exit == .payFine {
            // The fine is paid like a tax: to the Free Parking pot, and it counts for Monopolife.
            updatedState = try payTax(in: updatedState, playerID: playerID, amount: jailFine)
        }
        updatedState.players[index].jailTurn = nil
        return updatedState
    }

    /// Called when `playerID`'s turn starts: a jailed player starts one more turn in jail,
    /// or walks out for free once they have served the maximum.
    static func startJailTurn(of playerID: UUID, in state: inout GameState) {
        guard let index = state.players.firstIndex(where: { $0.id == playerID }),
              let turn = state.players[index].jailTurn else {
            return
        }
        state.players[index].jailTurn = turn < maximumJailTurns ? turn + 1 : nil
    }
}
