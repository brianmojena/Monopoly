import Foundation

enum BoardEventTargetKind: Equatable {
    case side
    case colorGroup
    case ownedProperty
    /// An owned property with a level above 0.
    case leveledProperty
    /// An owned, unmortgaged property below the maximum level.
    case upgradableProperty
    case wholeBoard
    case allPlayers
}

enum BoardEventEffect: Equatable {
    /// Every rent change lasts a set number of rounds; none is permanent.
    case rent(flat: Int, percent: Int, rounds: Int)
    /// Each owned property costs this much, split among its shareholders by stake.
    case chargeShareholders(perProperty: Int)
    /// The bank pays this much per owned property, split among its shareholders by stake.
    case payShareholders(perProperty: Int)
    case payEveryPlayer(Int)
    /// Every active player pays this much to the bank, or what they have.
    case chargeEveryPlayer(Int)
    case levelDown
    /// The property goes up one level for free.
    case levelUp
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
            text: "Todos quieren vivir cerca de la estrella, mientras dure la novedad.",
            targetKind: .colorGroup, effect: .rent(flat: 100, percent: 0, rounds: 4)
        ),
        BoardEvent(
            id: "summer-festival", emoji: "🎡", title: "Festival de verano",
            text: "Turistas por todas partes: las rentas se disparan.",
            targetKind: .side, effect: .rent(flat: 0, percent: 100, rounds: 2)
        ),
        BoardEvent(
            id: "subway", emoji: "🚇", title: "Nueva línea de metro",
            text: "La zona queda mejor conectada y todos quieren mudarse.",
            targetKind: .side, effect: .rent(flat: 50, percent: 0, rounds: 5)
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
            text: "Llegan estudiantes buscando dónde vivir durante el curso.",
            targetKind: .colorGroup, effect: .rent(flat: 0, percent: 50, rounds: 4)
        ),
        BoardEvent(
            id: "blackout", emoji: "💡", title: "Apagón",
            text: "Un lado del tablero se queda sin luz.",
            targetKind: .side, effect: .rent(flat: 0, percent: -50, rounds: 1)
        ),
        BoardEvent(
            id: "neighborhood-award", emoji: "🏆", title: "Barrio del año",
            text: "La propiedad gana un premio y todos quieren vivir ahí.",
            targetKind: .ownedProperty, effect: .rent(flat: 150, percent: 0, rounds: 3)
        ),
        BoardEvent(
            id: "rock-concert", emoji: "🎸", title: "Concierto de rock",
            text: "Una banda famosa toca en el barrio y no queda una cama libre.",
            targetKind: .side, effect: .rent(flat: 0, percent: 50, rounds: 1)
        ),
        BoardEvent(
            id: "world-cup", emoji: "🏟️", title: "Mundial de fútbol",
            text: "Aficionados de todo el mundo llegan a la ciudad.",
            targetKind: .wholeBoard, effect: .rent(flat: 0, percent: 30, rounds: 2)
        ),
        BoardEvent(
            id: "epidemic", emoji: "🦠", title: "Epidemia",
            text: "La gente se queda en casa y nadie se muda.",
            targetKind: .wholeBoard, effect: .rent(flat: 0, percent: -50, rounds: 2)
        ),
        BoardEvent(
            id: "urban-renewal", emoji: "🏗️", title: "Renovación urbana",
            text: "El ayuntamiento reforma la propiedad gratis.",
            targetKind: .upgradableProperty, effect: .levelUp
        ),
        BoardEvent(
            id: "shopping-mall", emoji: "🛍️", title: "Abre un centro comercial",
            text: "Tiendas nuevas atraen vecinos al barrio.",
            targetKind: .colorGroup, effect: .rent(flat: 75, percent: 0, rounds: 3)
        ),
        BoardEvent(
            id: "crime-wave", emoji: "🚨", title: "Ola de robos",
            text: "El barrio se vuelve inseguro y los inquilinos se van.",
            targetKind: .colorGroup, effect: .rent(flat: -100, percent: 0, rounds: 3)
        ),
        BoardEvent(
            id: "earthquake", emoji: "🌋", title: "Terremoto",
            text: "Hay que reparar grietas en todo un lado del tablero.",
            targetKind: .side, effect: .chargeShareholders(perProperty: 75)
        ),
        BoardEvent(
            id: "tax-audit", emoji: "🧾", title: "Auditoría de Hacienda",
            text: "Hacienda revisa las cuentas de todos.",
            targetKind: .allPlayers, effect: .chargeEveryPlayer(50)
        ),
        BoardEvent(
            id: "lottery", emoji: "🎰", title: "Lotería nacional",
            text: "Toca un pellizco a cada jugador.",
            targetKind: .allPlayers, effect: .payEveryPlayer(50)
        ),
        BoardEvent(
            id: "real-estate-dividends", emoji: "💰", title: "Dividendos inmobiliarios",
            text: "El banco premia a los dueños de un lado del tablero.",
            targetKind: .side, effect: .payShareholders(perProperty: 50)
        ),
        BoardEvent(
            id: "tourist-season", emoji: "🏖️", title: "Temporada turística",
            text: "Llegan turistas y todos quieren alquilar en esta zona.",
            targetKind: .side, effect: .rent(flat: 100, percent: 0, rounds: 2)
        ),
        BoardEvent(
            id: "snowstorm", emoji: "❄️", title: "Tormenta de nieve",
            text: "Las calles están cortadas y nadie llega.",
            targetKind: .side, effect: .rent(flat: -100, percent: 0, rounds: 2)
        ),
        BoardEvent(
            id: "rats", emoji: "🐀", title: "Plaga de ratas",
            text: "Nadie quiere vivir aquí hasta que llegue el fumigador.",
            targetKind: .ownedProperty, effect: .rent(flat: 0, percent: -50, rounds: 3)
        ),
        BoardEvent(
            id: "on-tv", emoji: "📺", title: "Sale en la tele",
            text: "Un programa de reformas la muestra y se pone de moda.",
            targetKind: .ownedProperty, effect: .rent(flat: 0, percent: 100, rounds: 2)
        ),
        BoardEvent(
            id: "property-tax", emoji: "🏠", title: "Impuesto predial",
            text: "Toca pagar el impuesto de cada propiedad.",
            targetKind: .wholeBoard, effect: .chargeShareholders(perProperty: 20)
        )
    ]

    static func event(withID id: String) -> BoardEvent? {
        all.first { $0.id == id }
    }
}
