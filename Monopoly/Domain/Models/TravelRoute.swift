import Foundation

/// Where a travel square sends the token, always moving forward (GAME_RULES section 5).
enum TravelRoute: String, Codable, CaseIterable, Equatable {
    case sameSide
    case nextSide
    case twoSidesAhead
    case threeSidesAhead
    case fullLap

    // Placeholder fares, like the rest of GAME_RULES section 9.
    var fare: Int {
        switch self {
        case .sameSide, .nextSide:
            return 100
        case .twoSidesAhead:
            return 200
        case .threeSidesAhead:
            return 300
        case .fullLap:
            return 400
        }
    }
}
