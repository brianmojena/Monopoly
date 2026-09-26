import Foundation

struct RentResult: Equatable {
    let state: GameState
    let amount: Int
    /// The rent was more than everything the payer had, so paying it bankrupted them
    /// (GAME_RULES section 6.1).
    var bankruptsPayer = false
}
