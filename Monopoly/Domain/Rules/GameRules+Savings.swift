import Foundation

// Savings accounts (GAME_RULES section 4.10). Only money the player doesn't owe can be
// saved, and every GO pays the interest into their cash.
extension GameRules {
    static let variableSavingsFirstRate = 10
    static let variableSavingsRateStep = 10
    static let variableSavingsMaximumRate = 50
    static let fixedSavingsFirstRate = 20
    static let fixedSavingsRateStep = 15

    /// 10% at the first GO, 10 points more at each GO without a withdrawal, up to 50%.
    static func variableSavingsRate(streak: Int) -> Int {
        min(variableSavingsMaximumRate, variableSavingsFirstRate + variableSavingsRateStep * streak)
    }

    /// 20% at the first GO, 15 points more at each one after.
    static func fixedSavingsRate(go: Int) -> Int {
        fixedSavingsFirstRate + fixedSavingsRateStep * (go - 1)
    }

    /// Interest a fixed deposit pays over all its GOs.
    static func fixedSavingsTotalInterest(amount: Int, terms: Int) -> Int {
        (1...max(1, terms)).reduce(0) { $0 + amount * fixedSavingsRate(go: $1) / 100 }
    }

    /// Cash minus everything the player owes on credit cards and to other players.
    static func savableAmount(for playerID: UUID, in state: GameState) -> Int {
        guard let player = state.players.first(where: { $0.id == playerID }) else {
            return 0
        }
        let owedToPlayers = state.playerLoans
            .filter { $0.borrowerID == playerID }
            .reduce(0) { $0 + $1.remainingDebt }
        return max(0, player.balance - player.creditCardDebt - owedToPlayers)
    }

    static func depositInVariableSavings(in state: GameState, playerID: UUID, amount: Int) throws -> GameState {
        let index = try requireCanSave(amount, playerID: playerID, in: state)
        var updatedState = state
        updatedState.players[index].balance -= amount
        updatedState.players[index].savings.variableBalance += amount
        return updatedState
    }

    /// Any withdrawal sends the variable rate back to 10%.
    static func withdrawFromVariableSavings(in state: GameState, playerID: UUID, amount: Int) throws -> GameState {
        let index = try requireSavingsPlayer(playerID, in: state)
        guard amount > 0, amount <= state.players[index].savings.variableBalance else {
            throw GameRuleError.invalidAmount(amount)
        }
        var updatedState = state
        updatedState.players[index].savings.variableBalance -= amount
        updatedState.players[index].savings.variableStreak = 0
        updatedState.players[index].balance += amount
        return updatedState
    }

    static func openFixedDeposit(in state: GameState, playerID: UUID, amount: Int, terms: Int) throws -> GameState {
        guard FixedDeposit.termRange.contains(terms) else {
            throw GameRuleError.invalidSavingsTerm(terms)
        }
        let index = try requireCanSave(amount, playerID: playerID, in: state)
        var updatedState = state
        updatedState.players[index].balance -= amount
        updatedState.players[index].savings.fixedDeposits.append(FixedDeposit(amount: amount, terms: terms))
        return updatedState
    }

    /// Pays each account's interest into the player's cash, and gives back the fixed
    /// deposits whose last GO this was.
    static func paySavingsAtGo(for playerID: UUID, in state: inout GameState) {
        guard let index = state.players.firstIndex(where: { $0.id == playerID }) else {
            return
        }
        var player = state.players[index]
        // An empty account doesn't climb, or saving at the last moment would start at 50%.
        if player.savings.variableBalance > 0 {
            let rate = variableSavingsRate(streak: player.savings.variableStreak)
            player.balance += player.savings.variableBalance * rate / 100
            player.savings.variableStreak += 1
        } else {
            player.savings.variableStreak = 0
        }
        for depositIndex in player.savings.fixedDeposits.indices {
            player.savings.fixedDeposits[depositIndex].gosPaid += 1
            let deposit = player.savings.fixedDeposits[depositIndex]
            player.balance += deposit.amount * fixedSavingsRate(go: deposit.gosPaid) / 100
            if deposit.gosRemaining <= 0 {
                player.balance += deposit.amount
            }
        }
        player.savings.fixedDeposits.removeAll { $0.gosRemaining <= 0 }
        state.players[index] = player
    }

    private static func requireSavingsPlayer(_ playerID: UUID, in state: GameState) throws -> Int {
        guard state.activeHouseRules.contains(.savingsAccounts) else {
            throw GameRuleError.savingsDisabled
        }
        guard let index = state.players.firstIndex(where: { $0.id == playerID }) else {
            throw GameRuleError.playerNotFound(playerID)
        }
        try requireActivePlayer(in: state, playerID: playerID)
        return index
    }

    private static func requireCanSave(_ amount: Int, playerID: UUID, in state: GameState) throws -> Int {
        let index = try requireSavingsPlayer(playerID, in: state)
        guard amount > 0 else {
            throw GameRuleError.invalidAmount(amount)
        }
        let balance = state.players[index].balance
        guard amount <= balance else {
            throw GameRuleError.insufficientFunds(playerID: playerID, required: amount, available: balance)
        }
        let savable = savableAmount(for: playerID, in: state)
        guard amount <= savable else {
            throw GameRuleError.savingsBlockedByDebt(savable: savable)
        }
        return index
    }
}
