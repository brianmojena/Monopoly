import Foundation

enum LifeCardKind: String, Codable, Equatable {
    /// Applies at once.
    case event
    /// The player accepts (paying `money`) or passes.
    case decision
    /// Applies only to a player who owns `requiredPossession`.
    case possession
    /// Tells the player where to move their physical token.
    case movement
}

enum LifeCardMoney: Equatable {
    case none
    case collect(Int)
    case pay(Int)
    case collectPerOwnedProperty(each: Int, maximum: Int)
    case collectFromEachOtherPlayer(Int)
}

struct LifeCard: Identifiable, Equatable {
    let id: String
    let title: String
    let text: String
    let kind: LifeCardKind
    let money: LifeCardMoney
    /// Happiness for each role; every role is always present.
    let happiness: [LifeRole: Int]
    /// Happiness every other active player gets, whatever their role.
    var othersHappiness: Int = 0
    var grantedPossession: LifePossession?
    var requiredPossession: LifePossession?
    var removesRequiredPossession = false

    func happiness(for role: LifeRole) -> Int {
        happiness[role] ?? 0
    }

    /// What a decision card costs to accept.
    var cost: Int {
        if case let .pay(amount) = money {
            return amount
        }
        return 0
    }
}

private func happiness(
    consumer: Int,
    entrepreneur: Int,
    saver: Int,
    social: Int,
    globetrotter: Int,
    lender: Int,
    minimalist: Int
) -> [LifeRole: Int] {
    [
        .consumer: consumer,
        .entrepreneur: entrepreneur,
        .saver: saver,
        .social: social,
        .globetrotter: globetrotter,
        .lender: lender,
        .minimalist: minimalist
    ]
}

// Placeholder deck (MONOPOLIFE_RULES section 5.1). Keep each role's total within
// ±2 of the others when changing it; `MonopolifeRulesTests` checks it. The Chameleon
// has no column: it uses its current disguise's.
enum LifeCards {
    static let all: [LifeCard] = [
        LifeCard(
            id: "buy-car", title: "Cómprate un carro", text: "Por fin el carro que querías.",
            kind: .decision, money: .pay(300),
            happiness: happiness(consumer: 7, entrepreneur: 3, saver: -2, social: 3, globetrotter: 6, lender: 1, minimalist: 0),
            grantedPossession: .car
        ),
        LifeCard(
            id: "big-tv", title: "Televisor gigante", text: "Noches de películas en casa.",
            kind: .decision, money: .pay(200),
            happiness: happiness(consumer: 5, entrepreneur: 1, saver: -1, social: 3, globetrotter: 0, lender: 0, minimalist: 0),
            grantedPossession: .television
        ),
        LifeCard(
            id: "food-truck", title: "Abres un food truck", text: "Tu propio negocio sobre ruedas.",
            kind: .decision, money: .pay(250),
            happiness: happiness(consumer: 2, entrepreneur: 8, saver: 0, social: 2, globetrotter: 1, lender: 3, minimalist: 0),
            grantedPossession: .foodTruck
        ),
        LifeCard(
            id: "beach-vacation", title: "Vacaciones en la playa", text: "Una semana de sol y mar.",
            kind: .decision, money: .pay(250),
            happiness: happiness(consumer: 3, entrepreneur: 1, saver: -2, social: 3, globetrotter: 8, lender: 0, minimalist: 4)
        ),
        LifeCard(
            id: "party", title: "Organizas una fiesta", text: "Invitas a todos. Cada otro jugador gana +1 de felicidad.",
            kind: .decision, money: .pay(150),
            happiness: happiness(consumer: 2, entrepreneur: 1, saver: -2, social: 7, globetrotter: 2, lender: 0, minimalist: 5),
            othersHappiness: 1
        ),
        LifeCard(
            id: "startup", title: "Inviertes en una startup", text: "Apuestas por una idea con futuro.",
            kind: .decision, money: .pay(200),
            happiness: happiness(consumer: 0, entrepreneur: 4, saver: 1, social: 1, globetrotter: 0, lender: 5, minimalist: 0)
        ),
        LifeCard(
            id: "pension-plan", title: "Plan de pensiones", text: "Tu yo del futuro te lo agradecerá.",
            kind: .decision, money: .pay(150),
            happiness: happiness(consumer: -1, entrepreneur: 1, saver: 7, social: 0, globetrotter: -1, lender: 5, minimalist: 3)
        ),
        LifeCard(
            id: "designer-clothes", title: "Ropa de marca", text: "Estrenas un look nuevo.",
            kind: .decision, money: .pay(100),
            happiness: happiness(consumer: 3, entrepreneur: 1, saver: -2, social: 2, globetrotter: 0, lender: 0, minimalist: 0)
        ),
        LifeCard(
            id: "car-breaks", title: "Se te rompe el carro", text: "Si tienes carro, pagas $150 de reparación.",
            kind: .possession, money: .pay(150),
            happiness: happiness(consumer: -3, entrepreneur: -2, saver: -4, social: -2, globetrotter: -5, lender: -3, minimalist: -1),
            requiredPossession: .car
        ),
        LifeCard(
            id: "tv-stolen", title: "Te roban el televisor", text: "Si tienes televisor, lo pierdes.",
            kind: .possession, money: .none,
            happiness: happiness(consumer: -5, entrepreneur: -1, saver: -2, social: -2, globetrotter: 0, lender: -2, minimalist: 0),
            requiredPossession: .television,
            removesRequiredPossession: true
        ),
        LifeCard(
            id: "food-truck-inspection", title: "Inspección al food truck", text: "Si tienes food truck, pagas $100 de multa.",
            kind: .possession, money: .pay(100),
            happiness: happiness(consumer: -1, entrepreneur: -4, saver: -2, social: -1, globetrotter: -1, lender: -2, minimalist: -1),
            requiredPossession: .foodTruck
        ),
        LifeCard(
            id: "sick", title: "Te enfermas", text: "Pagas $100 de medicinas.",
            kind: .event, money: .pay(100),
            happiness: happiness(consumer: -3, entrepreneur: -3, saver: -3, social: -3, globetrotter: -3, lender: -3, minimalist: -3)
        ),
        LifeCard(
            id: "traffic-fine", title: "Multa de tránsito", text: "Pagas $50.",
            kind: .event, money: .pay(50),
            happiness: happiness(consumer: -1, entrepreneur: -1, saver: -2, social: -1, globetrotter: -1, lender: -2, minimalist: -1)
        ),
        LifeCard(
            id: "layoffs", title: "Recorte de personal", text: "Pagas $150 mientras buscas otro trabajo.",
            kind: .event, money: .pay(150),
            happiness: happiness(consumer: -2, entrepreneur: -4, saver: -2, social: -2, globetrotter: -1, lender: -2, minimalist: -1)
        ),
        LifeCard(
            id: "market-crash", title: "La bolsa se desploma", text: "Pierdes $100.",
            kind: .event, money: .pay(100),
            happiness: happiness(consumer: -1, entrepreneur: -2, saver: -2, social: -1, globetrotter: 0, lender: -4, minimalist: 0)
        ),
        LifeCard(
            id: "flight-cancelled", title: "Vuelo cancelado", text: "Cobras $50 de compensación.",
            kind: .event, money: .collect(50),
            happiness: happiness(consumer: -1, entrepreneur: -1, saver: 1, social: -1, globetrotter: -4, lender: 1, minimalist: -2)
        ),
        LifeCard(
            id: "friend-fight", title: "Pelea con un amigo", text: "Una discusión que duele.",
            kind: .event, money: .none,
            happiness: happiness(consumer: -1, entrepreneur: -1, saver: -1, social: -5, globetrotter: -1, lender: -1, minimalist: -3)
        ),
        LifeCard(
            id: "go-to-jail", title: "Mala racha: a la cárcel", text: "Mueve tu ficha a la cárcel.",
            kind: .movement, money: .none,
            // Going to jail already costs every role the same (LifeRoleValues.jailed).
            happiness: happiness(consumer: 0, entrepreneur: 0, saver: 0, social: 0, globetrotter: 0, lender: 0, minimalist: 0)
        ),
        LifeCard(
            id: "birthday", title: "Tu cumpleaños", text: "Cada otro jugador te paga $20.",
            kind: .event, money: .collectFromEachOtherPlayer(20),
            happiness: happiness(consumer: 2, entrepreneur: 2, saver: 2, social: 5, globetrotter: 2, lender: 2, minimalist: 4)
        ),
        LifeCard(
            id: "year-end-bonus", title: "Bono de fin de año", text: "Cobras $150.",
            kind: .event, money: .collect(150),
            happiness: happiness(consumer: 3, entrepreneur: 2, saver: 6, social: 1, globetrotter: 2, lender: 4, minimalist: 1)
        ),
        LifeCard(
            id: "big-client", title: "Cliente importante", text: "Cobras $100.",
            kind: .event, money: .collect(100),
            happiness: happiness(consumer: 1, entrepreneur: 5, saver: 2, social: 1, globetrotter: 1, lender: 3, minimalist: 1)
        ),
        LifeCard(
            id: "dividends", title: "Dividendos", text: "Cobras $20 por cada propiedad en la que tienes acciones (máx $200).",
            kind: .event, money: .collectPerOwnedProperty(each: 20, maximum: 200),
            happiness: happiness(consumer: 1, entrepreneur: 2, saver: 3, social: 0, globetrotter: 0, lender: 4, minimalist: 0)
        ),
        LifeCard(
            id: "backpacking", title: "Viaje de mochilero", text: "Avanza tu ficha a Salida y cobra tu salario.",
            kind: .movement, money: .none,
            happiness: happiness(consumer: 0, entrepreneur: 1, saver: 2, social: 2, globetrotter: 7, lender: 0, minimalist: 5)
        ),
        LifeCard(
            id: "reunion", title: "Reencuentro con amigos", text: "Una noche para recordar.",
            kind: .event, money: .none,
            happiness: happiness(consumer: 2, entrepreneur: 1, saver: 1, social: 5, globetrotter: 3, lender: 1, minimalist: 5)
        ),
        LifeCard(
            id: "black-friday", title: "Black Friday", text: "Pagas $50 en ofertas.",
            kind: .event, money: .pay(50),
            happiness: happiness(consumer: 3, entrepreneur: 0, saver: 1, social: 1, globetrotter: 0, lender: 0, minimalist: -2)
        ),
        LifeCard(
            id: "perfect-day", title: "Un día perfecto", text: "Todo sale bien hoy.",
            kind: .event, money: .none,
            happiness: happiness(consumer: 3, entrepreneur: 3, saver: 3, social: 3, globetrotter: 3, lender: 3, minimalist: 3)
        ),
        LifeCard(
            id: "tax-refund", title: "Devolución de impuestos", text: "Cobras $100.",
            kind: .event, money: .collect(100),
            happiness: happiness(consumer: 1, entrepreneur: 2, saver: 5, social: 1, globetrotter: 1, lender: 4, minimalist: 1)
        ),
        LifeCard(
            id: "wedding-abroad", title: "Boda en otro país", text: "Pagas $100 de viaje y regalo.",
            kind: .event, money: .pay(100),
            happiness: happiness(consumer: 1, entrepreneur: 0, saver: -2, social: 4, globetrotter: 6, lender: -1, minimalist: 4)
        ),
        LifeCard(
            id: "coupons", title: "Cupones de descuento", text: "Cobras $30.",
            kind: .event, money: .collect(30),
            happiness: happiness(consumer: 1, entrepreneur: 0, saver: 5, social: 0, globetrotter: 0, lender: 3, minimalist: 2)
        ),
        LifeCard(
            id: "overtime", title: "Horas extra", text: "Cobras $100, pero te pierdes planes.",
            kind: .event, money: .collect(100),
            happiness: happiness(consumer: 1, entrepreneur: 3, saver: 4, social: -2, globetrotter: -2, lender: 3, minimalist: -2)
        )
    ]

    static func card(withID id: String) -> LifeCard? {
        all.first { $0.id == id }
    }
}
