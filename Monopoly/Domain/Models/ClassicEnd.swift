import Foundation

/// How a Classic game ends, set by the host before it starts (GAME_RULES section 7).
struct ClassicEndConditions: Codable, Equatable {
    static let netWorthGoalRange = 2_000...50_000
    static let netWorthGoalStep = 1_000
    static let defaultNetWorthGoal = 10_000

    /// Net worth that wins the game on the spot; nil turns the goal off.
    var netWorthGoal: Int?
    /// Bankruptcies that end the game; nil means until one player is left.
    var bankruptciesToEnd: Int?

    init(netWorthGoal: Int? = nil, bankruptciesToEnd: Int? = nil) {
        self.netWorthGoal = netWorthGoal
        self.bankruptciesToEnd = bankruptciesToEnd
    }
}

struct ClassicResult: Codable, Equatable {
    enum Reason: String, Codable {
        case netWorthGoal
        case bankruptcies
        case lastPlayerStanding
    }

    let winnerIDs: [UUID]
    let reason: Reason
    let round: Int
}
