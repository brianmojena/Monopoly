import Foundation

extension GameRules {
    static func payTravel(
        in state: GameState,
        playerID: UUID,
        route: TravelRoute
    ) throws -> GameState {
        guard let playerIndex = state.players.firstIndex(where: { $0.id == playerID }) else {
            throw GameRuleError.playerNotFound(playerID)
        }
        try requireActivePlayer(in: state, playerID: playerID)

        let player = state.players[playerIndex]
        guard player.balance >= route.fare else {
            throw GameRuleError.insufficientFunds(
                playerID: playerID,
                required: route.fare,
                available: player.balance
            )
        }

        var updatedState = state
        updatedState.players[playerIndex].balance -= route.fare
        depositInFreeParking(route.fare, in: &updatedState)
        applyLifeTrigger(.travelPaid(playerID: playerID), in: &updatedState)
        return updatedState
    }

    static func collectFreeParking(in state: GameState, playerID: UUID) throws -> GameState {
        guard state.activeHouseRules.contains(.freeParkingJackpot) else {
            throw GameRuleError.freeParkingDisabled
        }
        guard state.players.contains(where: { $0.id == playerID }) else {
            throw GameRuleError.playerNotFound(playerID)
        }
        try requireActivePlayer(in: state, playerID: playerID)
        guard state.freeParkingPot > 0 else {
            throw GameRuleError.freeParkingPotEmpty
        }

        var updatedState = state
        credit(state.freeParkingPot, to: playerID, in: &updatedState)
        updatedState.freeParkingPot = 0
        return updatedState
    }

    /// Money paid to the bank that GAME_RULES 8.2 sends to the pot; without the
    /// house rule it simply leaves the game.
    static func depositInFreeParking(_ amount: Int, in state: inout GameState) {
        guard amount > 0, state.activeHouseRules.contains(.freeParkingJackpot) else {
            return
        }
        state.freeParkingPot += amount
    }

    // Each payment carries interest in the same proportion as the debt still owed, so
    // the loan's last payment always carries exactly the interest that is left.
    static func interestPortion(of payment: Int, for loan: CreditCardLoan) -> Int {
        guard loan.remainingDebt > 0 else {
            return 0
        }
        return min(payment * loan.remainingInterest / loan.remainingDebt, loan.remainingInterest)
    }
}
