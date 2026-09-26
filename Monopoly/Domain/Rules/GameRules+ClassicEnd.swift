import Foundation

// The end of a Classic game (GAME_RULES section 7): a player reaching the net worth
// goal, or enough bankruptcies, after which the richest remaining player wins.
extension GameRules {
    /// Ends the game if a condition was met. The host runs it after every action.
    static func checkClassicEnd(in state: inout GameState) {
        guard state.mode == .classic, state.monopolife == nil, state.classicResult == nil, state.players.count > 1 else {
            return
        }
        let active = state.players.filter { $0.status == .active }
        let bankruptCount = state.players.count - active.count
        let lastStanding = state.players.count - 1
        let bankruptciesToEnd = min(state.endConditions.bankruptciesToEnd ?? lastStanding, lastStanding)

        if bankruptCount >= max(1, bankruptciesToEnd) {
            finish(
                winners: richest(among: active.map(\.id), in: state),
                reason: active.count <= 1 ? .lastPlayerStanding : .bankruptcies,
                in: &state
            )
            return
        }

        if let goal = state.endConditions.netWorthGoal {
            let reached = active.map(\.id).filter { netWorthOrBalance(of: $0, in: state) >= goal }
            if !reached.isEmpty {
                finish(winners: richest(among: reached, in: state), reason: .netWorthGoal, in: &state)
            }
        }
    }

    private static func finish(winners: [UUID], reason: ClassicResult.Reason, in state: inout GameState) {
        state.classicResult = ClassicResult(winnerIDs: winners, reason: reason, round: state.round)
        state.currentPlayerID = nil
    }

    /// Everyone tied for the highest net worth.
    private static func richest(among playerIDs: [UUID], in state: GameState) -> [UUID] {
        let worths = playerIDs.map { ($0, netWorthOrBalance(of: $0, in: state)) }
        guard let best = worths.map(\.1).max() else {
            return []
        }
        return worths.filter { $0.1 == best }.map(\.0)
    }

    static func netWorthOrBalance(of playerID: UUID, in state: GameState) -> Int {
        (try? netWorth(of: playerID, in: state))
            ?? state.players.first(where: { $0.id == playerID })?.balance
            ?? 0
    }
}
