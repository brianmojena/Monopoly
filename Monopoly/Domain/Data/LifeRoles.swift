import Foundation

// Placeholder values (MONOPOLIFE_RULES section 3.3). Every happiness number a role
// uses lives here so the balance can be tuned after playtesting without touching rules.
enum LifeRoleValues {
    static let consumerRentStep = 100
    static let consumerRentPointsCap = 6
    static let consumerLevelUp = 2
    static let consumerHoardingThreshold = 1500
    static let consumerHoarding = -2

    static let entrepreneurPointsPerProperty = 1
    static let entrepreneurPropertyPointsCap = 5
    static let entrepreneurRentReceived = 2
    static let entrepreneurMortgage = -3

    static let saverCashStep = 400
    static let saverSavingsPointsCap = 5
    static let saverSalaryWithoutDebt = 1
    static let saverLoan = -4

    static let socialDeal = 3
    static let socialScoredDealsPerRound = 2
    static let socialMinimumDealMoney = 50
    static let socialNoDeals = -1

    static let investorInvestmentCreated = 3
    static let investorPayout = 1
    static let investorPointsPerColorGroup = 1
    static let investorDiversificationPointsCap = 4
    static let investorTax = -2

    static let globetrotterSalary = 2
    static let globetrotterTrip = 2
    static let globetrotterStamp = 3
    static let globetrotterAllStamps = 8
    static let globetrotterPropertyBought = -2

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
    var definition: LifeRoleDefinition {
        switch self {
        case .consumer:
            return LifeRoleDefinition(
                role: self,
                name: "Consumista",
                emoji: "🛍️",
                summary: "Le gusta gastar y vivir en lugares caros.",
                likes: [
                    "Pagar renta: +1 por cada $100 pagados (máx +6 por pago).",
                    "Subir de nivel una propiedad en la que tienes acciones: +2."
                ],
                dislike: "Terminar la ronda con más de $1,500 en efectivo: −2."
            )
        case .entrepreneur:
            return LifeRoleDefinition(
                role: self,
                name: "Emprendedor",
                emoji: "🏢",
                summary: "Le gusta tener negocios y que la gente caiga en ellos.",
                likes: [
                    "Al terminar la ronda: +1 por cada propiedad en la que tienes acciones (máx +5).",
                    "Cada vez que otro jugador te paga renta: +2."
                ],
                dislike: "Hipotecar una propiedad que administras: −3."
            )
        case .saver:
            return LifeRoleDefinition(
                role: self,
                name: "Ahorrador",
                emoji: "🐷",
                summary: "Le gusta ver crecer su cuenta.",
                likes: [
                    "Al terminar la ronda: +1 por cada $400 en efectivo (máx +5).",
                    "Cobrar salario sin deuda de tarjeta: +1."
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
                    "Cada trato en el que participas: +3 (máx 2 por ronda). Debe mover al menos $50 o una acción. También cuenta cubrir la parte de otro accionista al subir de nivel, o recomprarle esas acciones."
                ],
                dislike: "Terminar una ronda sin haber participado en ningún trato: −1."
            )
        case .investor:
            return LifeRoleDefinition(
                role: self,
                name: "Inversionista",
                emoji: "📈",
                summary: "Le gusta diversificar y cobrar sin trabajar.",
                likes: [
                    "Crear una inversión como inversor: +3.",
                    "Cada vez que cobras el corte de una inversión: +1.",
                    "Al terminar la ronda: +1 por cada grupo de color en el que tienes acciones (máx +4)."
                ],
                dislike: "Pagar un impuesto (también el evento Revalúo de impuestos): −2."
            )
        case .globetrotter:
            return LifeRoleDefinition(
                role: self,
                name: "Trotamundos",
                emoji: "✈️",
                summary: "Le gusta viajar y conocer, no echar raíces.",
                likes: [
                    "Cobrar salario en Salida: +2.",
                    "Pagar un viaje en una casilla de viaje: +2.",
                    "La primera vez que pagas renta en cada grupo de color: +3. Con los 8 colores: +8 extra."
                ],
                dislike: "Comprar una propiedad al banco (compra, subasta o compra compartida): −2."
            )
        }
    }
}

extension LifeRoleEffect {
    var role: LifeRole {
        switch self {
        case .consumerRentPaid, .consumerLevelUp, .consumerHoardedCash:
            return .consumer
        case .entrepreneurOwnedProperties, .entrepreneurRentReceived, .entrepreneurMortgage:
            return .entrepreneur
        case .saverSavings, .saverSalaryWithoutDebt, .saverLoan:
            return .saver
        case .socialDeal, .socialNoDeals:
            return .social
        case .investorInvestmentCreated, .investorPayout, .investorDiversification, .investorTax:
            return .investor
        case .globetrotterSalary, .globetrotterTrip, .globetrotterStamp, .globetrotterAllStamps, .globetrotterPropertyBought:
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
        case .saverSavings:
            return "Tus ahorros al cerrar la ronda"
        case .saverSalaryWithoutDebt:
            return "Salario sin deudas"
        case .saverLoan:
            return "Pediste un préstamo"
        case .socialDeal:
            return "Cerraste un trato"
        case .socialNoDeals:
            return "Una ronda sin tratos"
        case .investorInvestmentCreated:
            return "Hiciste una inversión"
        case .investorPayout:
            return "Cobraste una inversión"
        case .investorDiversification:
            return "Tu cartera diversificada"
        case .investorTax:
            return "Pagaste impuestos"
        case .globetrotterSalary:
            return "Diste la vuelta al tablero"
        case .globetrotterTrip:
            return "Te fuiste de viaje"
        case .globetrotterStamp:
            return "Nuevo sello en tu pasaporte"
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
