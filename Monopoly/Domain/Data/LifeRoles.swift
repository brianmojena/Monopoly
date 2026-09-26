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

    static let chameleonDisguiseRounds = 3
    static let chameleonNewDisguise = 2

    static let lenderLoanGiven = 3
    static let lenderMinimumLoan = 100
    /// Only loans with interest count, so lending back and forth costs the borrower.
    static let lenderMinimumInterest = 10
    static let lenderScoredLoansPerRound = 1
    static let lenderPaymentReceived = 1
    static let lenderScoredPaymentsPerRound = 2
    static let lenderLoanRepaid = 3
    static let lenderCollateralTaken = 5
    static let lenderLoanLost = -3

    static let rivalAhead = 3
    static let rivalBehind = -1
    static let rivalRentFromTarget = 3
    static let rivalAuctionWon = 3
    static let rivalTargetSetback = 1
    static let rivalTargetBankrupt = 8

    static let minimalistGiftStep = 100
    static let minimalistGiftPointsCap = 3
    static let minimalistSimpleLife = 2
    static let minimalistMaximumProperties = 2
    static let minimalistPossession = -3

    /// MONOPOLIFE_RULES section 3.4: paying rent makes every role happy, more the
    /// more luxurious the place (board side 1–4 plus its level) and by role.
    static let rentVisitLuxuryPerPoint: [LifeRole: Int] = [
        .consumer: 2,
        .globetrotter: 2,
        .social: 3,
        .entrepreneur: 4,
        .saver: 4,
        .lender: 4,
        .minimalist: 4
    ]
    static let rentVisitMinimum = 1

    static func rentVisitPoints(for role: LifeRole, boardSide: Int, level: Int) -> Int {
        let luxury = boardSide + level
        return max(rentVisitMinimum, luxury / (rentVisitLuxuryPerPoint[role] ?? luxury))
    }

    /// MONOPOLIFE_RULES section 2: going to jail hurts every role the same.
    static let jailed = -3

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
        case .chameleon:
            return LifeRoleDefinition(
                role: self,
                name: "Camaleón",
                emoji: "🦎",
                summary: "Cambia de personalidad cada pocas rondas.",
                likes: [
                    "Empiezas con la personalidad de otro rol al azar y cada \(LifeRoleValues.chameleonDisguiseRounds) rondas cambias a otra distinta. Te hace feliz lo que le gusta a esa personalidad, y las Tarjetas de Vida te afectan como a ella.",
                    "Cada cambio de personalidad: +\(LifeRoleValues.chameleonNewDisguise).",
                    rentVisitLike
                ],
                dislike: "Lo que no le gusta a tu personalidad actual."
            )
        case .lender:
            return LifeRoleDefinition(
                role: self,
                name: "Prestamista",
                emoji: "🦈",
                summary: "Le gusta ser el banco de los demás.",
                likes: [
                    "Prestarle $\(LifeRoleValues.lenderMinimumLoan) o más a otro jugador con al menos \(LifeRoleValues.lenderMinimumInterest)% de interés: +3 (máx 1 por ronda).",
                    "Cada pago que recibes de un préstamo (cuota en Salida, % de rentas, plazo o pago anticipado): +1 (máx 2 por ronda).",
                    "Que te terminen de pagar un préstamo: +3.",
                    "Quedarte con la garantía de un préstamo sin pagar: +5.",
                    rentVisitLike
                ],
                dislike: "Perdonar una deuda, o que tu deudor quiebre sin que te quedes con una garantía: −3."
            )
        case .minimalist:
            return LifeRoleDefinition(
                role: self,
                name: "Minimalista",
                emoji: "🧘",
                summary: "Le gusta vivir con poco y compartir lo que tiene.",
                likes: [
                    "Regalarle dinero a otro jugador (transferencia): +1 por cada $\(LifeRoleValues.minimalistGiftStep) regalados en la ronda (máx +\(LifeRoleValues.minimalistGiftPointsCap)).",
                    "Terminar la ronda con acciones en \(LifeRoleValues.minimalistMaximumProperties) propiedades o menos y sin posesiones: +\(LifeRoleValues.minimalistSimpleLife).",
                    rentVisitLike
                ],
                dislike: "Conseguir una posesión (carro, televisor o food truck): −3."
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
        case .lenderLoanGiven, .lenderPaymentReceived, .lenderLoanRepaid, .lenderCollateralTaken, .lenderLoanLost:
            return .lender
        case .rivalAhead, .rivalBehind, .rivalRentFromTarget, .rivalAuctionWon, .rivalTargetSetback, .rivalTargetBankrupt:
            return nil
        case .minimalistGift, .minimalistSimpleLife, .minimalistPossession:
            return .minimalist
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
        case .lenderLoanGiven:
            return "Prestaste dinero"
        case .lenderPaymentReceived:
            return "Te pagaron una cuota"
        case .lenderLoanRepaid:
            return "Te pagaron un préstamo completo"
        case .lenderCollateralTaken:
            return "Te quedaste con una garantía"
        case .lenderLoanLost:
            return "Perdiste un préstamo"
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
        case .minimalistGift:
            return "Regalaste dinero"
        case .minimalistSimpleLife:
            return "Vida simple"
        case .minimalistPossession:
            return "Acumulaste cosas"
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
