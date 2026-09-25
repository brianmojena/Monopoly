import Foundation

/// Physical cards the host resolves by hand from the app (GAME_RULES section 8.5).
enum HostCard: String, Codable, CaseIterable, Identifiable {
    /// Rent drops $100 on one side of the board.
    case rentDropOnSide
    /// Rent rises $100 on one side of the board.
    case rentRaiseOnSide
    /// Rent rises $100 on one side and drops $100 on the two sides next to it.
    case rentShiftToSide
    /// A player moves to an owned property and it goes up one level for free.
    case advanceAndLevelUp

    static let rentChange = 100

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .rentDropOnSide:
            return "📉"
        case .rentRaiseOnSide:
            return "📈"
        case .rentShiftToSide:
            return "🔀"
        case .advanceAndLevelUp:
            return "🚀"
        }
    }

    var title: String {
        switch self {
        case .rentDropOnSide:
            return "Bajan las rentas"
        case .rentRaiseOnSide:
            return "Suben las rentas"
        case .rentShiftToSide:
            return "Todos se mudan a un lado"
        case .advanceAndLevelUp:
            return "Avanza y mejora"
        }
    }

    var text: String {
        switch self {
        case .rentDropOnSide:
            return "La renta de un lado del tablero baja $\(Self.rentChange)."
        case .rentRaiseOnSide:
            return "La renta de un lado del tablero sube $\(Self.rentChange)."
        case .rentShiftToSide:
            return "La renta de un lado sube $\(Self.rentChange) y la de sus dos lados vecinos baja $\(Self.rentChange)."
        case .advanceAndLevelUp:
            return "Un jugador mueve su ficha a una propiedad con dueño, que sube un nivel gratis."
        }
    }

    /// Whether the card changes rents on a side, so the host picks a side and a duration.
    var changesRent: Bool {
        self != .advanceAndLevelUp
    }
}

/// What the host chose when playing a card.
struct HostCardPlay: Codable, Equatable {
    let card: HostCard
    /// 1 to 4, going around the board from GO; for rent cards.
    var side: Int?
    /// How many rounds the rent change lasts, counting the current one; nil is permanent.
    var rounds: Int?
    /// The player who moves; for `advanceAndLevelUp`.
    var playerID: UUID?
    /// The property that goes up a level; for `advanceAndLevelUp`.
    var propertyID: UUID?

    init(card: HostCard, side: Int? = nil, rounds: Int? = nil, playerID: UUID? = nil, propertyID: UUID? = nil) {
        self.card = card
        self.side = side
        self.rounds = rounds
        self.playerID = playerID
        self.propertyID = propertyID
    }
}

/// A card the host played, kept so every device can announce it.
struct HostCardOccurrence: Codable, Equatable, Identifiable {
    let sequence: Int
    let play: HostCardPlay
    /// The round the card was played in.
    let round: Int

    var id: Int { sequence }
}

extension BoardEventsState {
    /// The two sides next to `side`, going around the board.
    static func neighbors(ofSide side: Int) -> [Int] {
        [(side + 2) % 4 + 1, side % 4 + 1]
    }
}
