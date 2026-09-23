import Foundation

enum HouseRule: String, Codable, CaseIterable, Equatable, Hashable {
    case freeParkingJackpot
    case doubleRentBeforeBuilding
    case noAuction
    case randomHomeBonus
    case customStartingBalance
    case creditCards
    /// Players only see the level of properties they hold shares in.
    case hiddenPropertyLevels
}
