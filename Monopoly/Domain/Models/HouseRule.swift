import Foundation

enum HouseRule: String, Codable, CaseIterable, Equatable, Hashable {
    case freeParkingJackpot
    case doubleRentBeforeBuilding
    case noAuction
    case randomHomeBonus
    case customStartingBalance
}
