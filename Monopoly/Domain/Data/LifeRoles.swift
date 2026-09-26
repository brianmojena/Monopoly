import Foundation

// Placeholder values (MONOPOLIFE_RULES section 3.3). Every happiness number a role
// uses lives here so the balance can be tuned after playtesting without touching rules.
enum LifeRoleValues {
    static let consumerRentStep = 100
    static let consumerRentPointsCap = 6
    static let consumerLevelUp = 2
    static let consumerHoardingThreshold = 1500
    static let consumerHoarding = -2

    static let entrepreneurPointsPerLeveledProperty = 1
    static let entrepreneurLeveledPropertyPointsCap = 4
    static let entrepreneurRentReceived = 1
    static let entrepreneurScoredRentsPerRound = 3
    static let entrepreneurMortgage = -3
    static let entrepreneurStagnationRounds = 3
    static let entrepreneurStagnation = -2

    static let saverCashStep = 300
    static let saverSavingsPointsCap = 5
    static let saverSalaryWithoutDebt = 2
    static let saverLoan = -4

    static let socialDeal = 3
    static let socialScoredDealsPerRound = 2
    static let socialMinimumDealMoney = 50
    static let socialVisit = 1
    static let socialNoDeals = -1
    /// The first rounds are for getting started, so a round without deals only
    /// counts from this one on.
    static let socialNoDealsFromRound = 3

    static let globetrotterSalary = 3
    static let globetrotterTrip = 3
    static let globetrotterStamp = 3
    static let globetrotterRevisit = 1
    static let globetrotterAllStamps = 8
    static let globetrotterPropertyBought = -2
    /// Properties the Globetrotter can hold before buying another one bothers them.
    static let globetrotterPropertiesWithoutRoots = 2

    /// MONOPOLIFE_RULES section 3.4: paying rent makes every role happy, more the
    /// more luxurious the place (board side 1–4 plus its level) and by role.
    static let rentVisitLuxuryPerPoint: [LifeRole: Int] = [
        .consumer: 2,
        .globetrotter: 2,
        .social: 3,
        .entrepreneur: 4,
        .saver: 4
    ]
    static let rentVisitMinimum = 1

    static func rentVisitPoints(for role: LifeRole, boardSide: Int, level: Int) -> Int {
        let luxury = boardSide + level
        return max(rentVisitMinimum, luxury / (rentVisitLuxuryPerPoint[role] ?? luxury))
    }

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
        let perPoint = LifeRoleValues.rentVisitLuxuryPerPoint[self] ?? 1
        return "Pagar renta: +1 por cada \(perPoint) de lujo (lado del tablero 1–4 + nivel de la propiedad), mínimo +\(LifeRoleValues.rentVisitMinimum)."
    }

    var definition: LifeRoleDefinition {
        switch self {
        case .consumer:
            return LifeRoleDefinition(
                role: self,
                name: "Consumista",
                emoji: "🛍️",
                summary: "Le gusta gastar y vivir en lugares caros.",
                likes: [
                    rentVisitLike,
                    "Además, al pagar renta: +1 por cada $100 pagados (máx +6 por pago).",
                    "Subir de nivel una propiedad en la que tienes acciones: +2."
                ],
                dislike: "Terminar la ronda con más de $1,500 en efectivo: −2."
            )
        case .entrepreneur:
            return LifeRoleDefinition(
                role: self,
                name: "Emprendedor",
                emoji: "🏢",
                summary: "Le gusta construir negocios y que la gente caiga en ellos.",
                likes: [
                    "Al terminar la ronda: +1 por cada propiedad que administras con nivel 1 o más (máx +4).",
                    "Cada vez que otro jugador te paga renta: +1 (máx 3 por ronda).",
                    rentVisitLike
                ],
                dislike: "Hipotecar una propiedad que administras: −3. Pasar 3 rondas seguidas sin subir de nivel ninguna propiedad: −2 al terminar cada ronda hasta que subas una."
            )
        case .saver:
            return LifeRoleDefinition(
                role: self,
                name: "Ahorrador",
                emoji: "🐷",
                summary: "Le gusta ver crecer su cuenta.",
                likes: [
                    "Al terminar tu turno: +1 por cada $300 en efectivo (máx +5).",
                    "Cobrar salario sin deuda de tarjeta: +2.",
                    rentVisitLike
                ],
                dislike: "Pedir un préstamo de tarjeta de crédito: −4."
            )
        case .social:
            return LifeRoleDefinition(
                role: self,
                name: "Social",
                emoji: "🎉",
                summary: "Le gusta negociar y compartir.",
                likes: [
                    "Cada trato en el que participas: +3 (máx 2 por ronda). Debe mover al menos $50 o una acción. También cuenta cubrir la parte de otro accionista al subir de nivel, o recomprarle esas acciones.",
                    "Pagarle o cobrarle renta a un jugador por primera vez en la ronda: +1 por cada jugador distinto.",
                    rentVisitLike
                ],
                dislike: "Desde la ronda \(LifeRoleValues.socialNoDealsFromRound): terminar una ronda sin haber participado en ningún trato: −1."
            )
        case .globetrotter:
            return LifeRoleDefinition(
                role: self,
                name: "Trotamundos",
                emoji: "✈️",
                summary: "Le gusta viajar y conocer, no echar raíces.",
                likes: [
                    "Cobrar salario en Salida: +3.",
                    "Pagar un viaje en una casilla de viaje: +3.",
                    "La primera vez que pagas renta en cada grupo de color: +3 (sello). Con los 8 sellos: +8 extra. Volver a pagar renta en un grupo ya sellado: +1.",
                    rentVisitLike
                ],
                dislike: "Comprar una propiedad al banco (compra, subasta o compra compartida) cuando ya tienes acciones en 2 o más: −2."
            )
        }
    }
}

extension LifeRoleEffect {
    var role: LifeRole {
        switch self {
        case .consumerRentPaid, .consumerLevelUp, .consumerHoardedCash:
            return .consumer
        case .entrepreneurOwnedProperties, .entrepreneurRentReceived, .entrepreneurMortgage, .entrepreneurStagnation:
            return .entrepreneur
        case .saverSavings, .saverSalaryWithoutDebt, .saverLoan:
            return .saver
        case .socialDeal, .socialVisit, .socialNoDeals:
            return .social
        case .globetrotterSalary, .globetrotterTrip, .globetrotterStamp, .globetrotterRevisit,
             .globetrotterAllStamps, .globetrotterPropertyBought:
            return .globetrotter
        }
    }

    var description: String {
        switch self {
        case .consumerRentPaid:
            return "Pagaste renta en un lugar caro"
        case .consumerLevelUp:
            return "Mejoraste una propiedad"
        case .consumerHoardedCash:
            return "Demasiado dinero guardado"
        case .entrepreneurOwnedProperties:
            return "Tus negocios al cerrar la ronda"
        case .entrepreneurRentReceived:
            return "Alguien cayó en tu negocio"
        case .entrepreneurMortgage:
            return "Hipotecaste un negocio"
        case .entrepreneurStagnation:
            return "Tus negocios están estancados"
        case .saverSavings:
            return "Tus ahorros al terminar tu turno"
        case .saverSalaryWithoutDebt:
            return "Salario sin deudas"
        case .saverLoan:
            return "Pediste un préstamo"
        case .socialDeal:
            return "Cerraste un trato"
        case .socialVisit:
            return "Te viste con alguien"
        case .socialNoDeals:
            return "Una ronda sin tratos"
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
