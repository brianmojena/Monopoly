import Foundation

enum BoardEventTargetKind: Equatable {
    case side
    case colorGroup
    case ownedProperty
    /// An owned property with a level above 0.
    case leveledProperty
    case wholeBoard
    case allPlayers
}

enum BoardEventEffect: Equatable {
    /// `rounds` nil means permanent.
    case rent(flat: Int, percent: Int, rounds: Int?)
    /// Each owned property costs this much, split among its shareholders by stake.
    case chargeShareholders(perProperty: Int)
    case payEveryPlayer(Int)
    case levelDown
}

struct BoardEvent: Identifiable, Equatable {
    let id: String
    let emoji: String
    let title: String
    let text: String
    let targetKind: BoardEventTargetKind
    let effect: BoardEventEffect
}

// Placeholder values (GAME_RULES section 8.3).
enum BoardEventCatalog {
    static let all: [BoardEvent] = [
        BoardEvent(
            id: "tornado", emoji: "🌪️", title: "Tornado",
            text: "Un tornado arrasa un lado del tablero: nadie quiere alquilar ahí.",
            targetKind: .side, effect: .rent(flat: -200, percent: 0, rounds: 3)
        ),
        BoardEvent(
            id: "celebrity", emoji: "⭐", title: "Un famoso se muda al barrio",
            text: "Todos quieren vivir cerca de la estrella.",
            targetKind: .colorGroup, effect: .rent(flat: 100, percent: 0, rounds: nil)
        ),
        BoardEvent(
            id: "summer-festival", emoji: "🎡", title: "Festival de verano",
            text: "Turistas por todas partes: las rentas se disparan.",
            targetKind: .side, effect: .rent(flat: 0, percent: 100, rounds: 2)
        ),
        BoardEvent(
            id: "subway", emoji: "🚇", title: "Nueva línea de metro",
            text: "La zona queda mejor conectada para siempre.",
            targetKind: .side, effect: .rent(flat: 50, percent: 0, rounds: nil)
        ),
        BoardEvent(
            id: "roadworks", emoji: "🚧", title: "Obras en la calle",
            text: "Nadie puede llegar a esta propiedad.",
            targetKind: .ownedProperty, effect: .rent(flat: 0, percent: -100, rounds: 2)
        ),
        BoardEvent(
            id: "flood", emoji: "🌊", title: "Inundación",
            text: "El agua daña las propiedades de un lado del tablero.",
            targetKind: .side, effect: .chargeShareholders(perProperty: 50)
        ),
        BoardEvent(
            id: "fire", emoji: "🔥", title: "Incendio",
            text: "Un incendio destruye una mejora de la propiedad.",
            targetKind: .leveledProperty, effect: .levelDown
        ),
        BoardEvent(
            id: "housing-boom", emoji: "📈", title: "Boom inmobiliario",
            text: "Todo el mundo quiere alquilar.",
            targetKind: .wholeBoard, effect: .rent(flat: 0, percent: 25, rounds: 3)
        ),
        BoardEvent(
            id: "recession", emoji: "📉", title: "Crisis económica",
            text: "La gente ajusta el cinturón y las rentas bajan.",
            targetKind: .wholeBoard, effect: .rent(flat: 0, percent: -25, rounds: 3)
        ),
        BoardEvent(
            id: "subsidy", emoji: "🏛️", title: "Subsidio del gobierno",
            text: "El banco reparte dinero a todos los jugadores.",
            targetKind: .allPlayers, effect: .payEveryPlayer(100)
        ),
        BoardEvent(
            id: "tax-reassessment", emoji: "💸", title: "Revalúo de impuestos",
            text: "Suben los impuestos de un barrio.",
            targetKind: .colorGroup, effect: .chargeShareholders(perProperty: 30)
        ),
        BoardEvent(
            id: "university", emoji: "🎓", title: "Abre una universidad",
            text: "Llegan estudiantes buscando dónde vivir.",
            targetKind: .colorGroup, effect: .rent(flat: 0, percent: 50, rounds: nil)
        ),
        BoardEvent(
            id: "blackout", emoji: "💡", title: "Apagón",
            text: "Un lado del tablero se queda sin luz.",
            targetKind: .side, effect: .rent(flat: 0, percent: -50, rounds: 1)
        ),
        BoardEvent(
            id: "neighborhood-award", emoji: "🏆", title: "Barrio del año",
            text: "La propiedad gana un premio y todos quieren vivir ahí.",
            targetKind: .ownedProperty, effect: .rent(flat: 150, percent: 0, rounds: nil)
        )
    ]

    static func event(withID id: String) -> BoardEvent? {
        all.first { $0.id == id }
    }
}
