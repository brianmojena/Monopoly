import Foundation

// Placeholder values (MONOPOLIFE_RULES section 3.3). Every happiness number a role
// uses lives here so the balance can be tuned after playtesting without touching rules.
enum LifeRoleValues {
    static let consumerSpendingStep = 70
    static let consumerSpendingPointsCap = 5
    static let consumerHoardingThreshold = 2000
    static let consumerHoarding = -2

    static let entrepreneurRentStep = 75
    static let entrepreneurRentPointsCap = 6
    /// The Entrepreneur gets +1 per this much paid to level up, at least +1.
    static let entrepreneurLevelUpStep = 100
    static let entrepreneurMortgage = -3

    static let saverCashStep = 350
    static let saverSavingsPointsCap = 4
    static let saverSalaryWithoutDebt = 2
    static let saverLoan = -4

    static let socialInteraction = 3
    static let socialScoredInteractionsPerRound = 3
    /// The least a gift or a deal must move to count as an interaction.
    static let socialMinimumGift = 50
    static let socialLonely = -2
    /// The first round is for getting started, so a lonely round only counts from this one on.
    static let socialLonelyFromRound = 2

    static let globetrotterSalary = 5
    static let globetrotterTrip = 5
    static let globetrotterStamp = 4
    static let globetrotterRevisit = 1
    static let globetrotterAllStamps = 8
    static let globetrotterPropertyBought = -2
    /// Properties the Globetrotter can hold before buying another one bothers them.
    static let globetrotterPropertiesWithoutRoots = 2

    static let chameleonDisguiseRounds = 3
    static let chameleonNewDisguise = 1

    static let rivalAhead = 3
    static let rivalBehind = -1
    static let rivalRentFromTarget = 3
    static let rivalAuctionWon = 3
    static let rivalTargetSetback = 1
    static let rivalTargetBankrupt = 8

    /// MONOPOLIFE_RULES section 3.4: paying rent makes every role happy: a base that
    /// levels out the roles, plus more the more luxurious the place (board side 1–4
    /// plus its level), by role.
    static let rentVisitLuxuryPerPoint: [LifeRole: Int] = [
        .consumer: 2,
        .globetrotter: 2,
        .social: 3,
        .entrepreneur: 4,
        .saver: 4
    ]
    static let rentVisitBase = 10

    static func rentVisitPoints(for role: LifeRole, boardSide: Int, level: Int) -> Int {
        let luxury = boardSide + level
        return rentVisitBase + luxury / (rentVisitLuxuryPerPoint[role] ?? luxury)
    }

    /// MONOPOLIFE_RULES section 2: going to jail hurts every role the same.
    static let jailed = -3
    /// Each turn that starts in jail (the 1st, 2nd and 3rd), on top of going there.
    static let jailTurn = -2

    /// MONOPOLIFE_RULES section 6.
    static let bankruptcyRescueBalance = 500
}

struct LifeRoleDefinition {
    let role: LifeRole
    let name: String
    let emoji: String
    let summary: String
    let likes: [String]
    let dislike: String
}

extension LifeRole {
    /// The rent-paying like every role shares, with this role's rate.
    var rentVisitLike: String {
        guard self != .chameleon else {
            return "Pagar renta: te hace feliz según tu personalidad actual."
        }
        let perPoint = LifeRoleValues.rentVisitLuxuryPerPoint[self] ?? 1
        return "Pagar renta: +\(LifeRoleValues.rentVisitBase), más +1 por cada \(perPoint) de lujo (lado del tablero 1–4 + nivel de la propiedad)."
    }

    var definition: LifeRoleDefinition {
        typealias V = LifeRoleValues
        switch self {
        case .consumer:
            return LifeRoleDefinition(
                role: self,
                name: "Consumista",
                emoji: "🛍️",
                summary: "Le gusta gastar: comprar, mejorar, salir y viajar.",
                likes: [
                    "Al terminar tu turno: +1 por cada $\(V.consumerSpendingStep) que gastaste desde tu turno anterior (máx +\(V.consumerSpendingPointsCap)). Cuenta comprar propiedades, subir de nivel, pagar renta, pagar viajes y comprar en Tarjetas de Vida. Bajar de nivel resta lo que te devuelven.",
                    rentVisitLike
                ],
                dislike: "Terminar la ronda con más de $\(V.consumerHoardingThreshold.formatted()) en efectivo: \(V.consumerHoarding)."
            )
        case .entrepreneur:
            return LifeRoleDefinition(
                role: self,
                name: "Emprendedor",
                emoji: "🏢",
                summary: "Le gusta construir negocios y que la gente caiga en ellos.",
                likes: [
                    "Cobrar renta: +1 por cada $\(V.entrepreneurRentStep) que te pagan (máx +\(V.entrepreneurRentPointsCap) por ronda).",
                    "Subir de nivel una propiedad que administras: +1 por cada $\(V.entrepreneurLevelUpStep) que pagas (mínimo +1).",
                    rentVisitLike
                ],
                dislike: "Hipotecar una propiedad que administras: \(V.entrepreneurMortgage)."
            )
        case .saver:
            return LifeRoleDefinition(
                role: self,
                name: "Ahorrador",
                emoji: "🐷",
                summary: "Le gusta ver crecer su cuenta.",
                likes: [
                    "Al terminar tu turno: +1 por cada $\(V.saverCashStep) en efectivo (máx +\(V.saverSavingsPointsCap)).",
                    "Cobrar salario sin deuda de tarjeta: +\(V.saverSalaryWithoutDebt).",
                    rentVisitLike
                ],
                dislike: "Pedir un préstamo de tarjeta de crédito: \(V.saverLoan)."
            )
        case .social:
            return LifeRoleDefinition(
                role: self,
                name: "Social",
                emoji: "🎉",
                summary: "Le gusta tratar con todos: cobrar, pagar, negociar y regalar.",
                likes: [
                    "Cada vez que se mueve dinero entre tú y otro jugador: +\(V.socialInteraction) (máx \(V.socialScoredInteractionsPerRound) veces por ronda). Cuenta pagarle o cobrarle renta, cerrar un trato del Mercado con él, o regalarle $\(V.socialMinimumGift) o más con un pago libre (también si te lo regala a ti).",
                    rentVisitLike
                ],
                dislike: "Desde la ronda \(V.socialLonelyFromRound): terminar una ronda sin ningún movimiento de dinero con otro jugador: \(V.socialLonely)."
            )
        case .globetrotter:
            return LifeRoleDefinition(
                role: self,
                name: "Trotamundos",
                emoji: "✈️",
                summary: "Le gusta viajar y conocer, no echar raíces.",
                likes: [
                    "Cobrar salario en Salida: +\(V.globetrotterSalary).",
                    "Pagar un viaje en una casilla de viaje: +\(V.globetrotterTrip).",
                    "La primera vez que pagas renta en cada grupo de color: +\(V.globetrotterStamp) (sello). Con los 8 sellos: +\(V.globetrotterAllStamps) extra. Volver a pagar renta en un grupo ya sellado: +\(V.globetrotterRevisit).",
                    rentVisitLike
                ],
                dislike: "Comprar una propiedad al banco (compra, subasta o compra compartida) cuando ya tienes acciones en \(V.globetrotterPropertiesWithoutRoots) o más: \(V.globetrotterPropertyBought)."
            )
        case .chameleon:
            return LifeRoleDefinition(
                role: self,
                name: "Camaleón",
                emoji: "🦎",
                summary: "Cambia de personalidad cada pocas rondas.",
                likes: [
                    "Empiezas con la personalidad de otro rol al azar y cada \(V.chameleonDisguiseRounds) rondas cambias a otra distinta. Te hace feliz lo que le gusta a esa personalidad, y las Tarjetas de Vida te afectan como a ella.",
                    "Cada cambio de personalidad: +\(V.chameleonNewDisguise).",
                    rentVisitLike
                ],
                dislike: "Lo que no le gusta a tu personalidad actual."
            )
        }
    }
}

/// MONOPOLIFE_RULES section 3.5: every player has a secret rival, whatever their role.
enum Rivalry {
    static let rules = [
        "Terminar la ronda con más patrimonio que tu rival: +\(LifeRoleValues.rivalAhead). Con menos: \(LifeRoleValues.rivalBehind).",
        "Que tu rival te pague renta: +\(LifeRoleValues.rivalRentFromTarget).",
        "Ganarle una subasta a tu rival (si también pujó): +\(LifeRoleValues.rivalAuctionWon).",
        "Que tu rival vaya a la cárcel o hipoteque una propiedad: +\(LifeRoleValues.rivalTargetSetback).",
        "Que tu rival quiebre: +\(LifeRoleValues.rivalTargetBankrupt)."
    ]
}

extension LifeRoleEffect {
    /// The role that has this like or dislike, or nil for the rivalry every player has.
    var role: LifeRole? {
        switch self {
        case .consumerSpending, .consumerHoardedCash:
            return .consumer
        case .entrepreneurRentReceived, .entrepreneurLevelUp, .entrepreneurMortgage:
            return .entrepreneur
        case .saverSavings, .saverSalaryWithoutDebt, .saverLoan:
            return .saver
        case .socialInteraction, .socialLonely:
            return .social
        case .globetrotterSalary, .globetrotterTrip, .globetrotterStamp, .globetrotterRevisit,
             .globetrotterAllStamps, .globetrotterPropertyBought:
            return .globetrotter
        case .rivalAhead, .rivalBehind, .rivalRentFromTarget, .rivalAuctionWon, .rivalTargetSetback, .rivalTargetBankrupt:
            return nil
        }
    }

    var description: String {
        switch self {
        case .consumerSpending:
            return "Lo que gastaste"
        case .consumerHoardedCash:
            return "Demasiado dinero guardado"
        case .entrepreneurRentReceived:
            return "Alguien cayó en tu negocio"
        case .entrepreneurLevelUp:
            return "Hiciste crecer un negocio"
        case .entrepreneurMortgage:
            return "Hipotecaste un negocio"
        case .saverSavings:
            return "Tus ahorros al terminar tu turno"
        case .saverSalaryWithoutDebt:
            return "Salario sin deudas"
        case .saverLoan:
            return "Pediste un préstamo"
        case .socialInteraction:
            return "Trataste con alguien"
        case .socialLonely:
            return "Una ronda sin ver a nadie"
        case .globetrotterSalary:
            return "Diste la vuelta al tablero"
        case .globetrotterTrip:
            return "Te fuiste de viaje"
        case .globetrotterStamp:
            return "Nuevo sello en tu pasaporte"
        case .globetrotterRevisit:
            return "Volviste a un lugar conocido"
        case .globetrotterAllStamps:
            return "¡Pasaporte completo!"
        case .globetrotterPropertyBought:
            return "Echaste raíces comprando"
        case .rivalAhead:
            return "Vas por delante de tu rival"
        case .rivalBehind:
            return "Tu rival va por delante"
        case .rivalRentFromTarget:
            return "Tu rival te pagó renta"
        case .rivalAuctionWon:
            return "Le ganaste una subasta a tu rival"
        case .rivalTargetSetback:
            return "A tu rival le fue mal"
        case .rivalTargetBankrupt:
            return "Tu rival quebró"
        }
    }
}

extension LifePossession {
    var name: String {
        switch self {
        case .car:
            return "Carro"
        case .television:
            return "Televisor"
        case .foodTruck:
            return "Food truck"
        }
    }

    var emoji: String {
        switch self {
        case .car:
            return "🚗"
        case .television:
            return "📺"
        case .foodTruck:
            return "🚚"
        }
    }
}
