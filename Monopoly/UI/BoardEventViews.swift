import SwiftUI

extension ColorGroup {
    var displayName: String {
        switch self {
        case .brown:
            return "Marrón"
        case .lightBlue:
            return "Celeste"
        case .pink:
            return "Rosa"
        case .orange:
            return "Naranja"
        case .red:
            return "Rojo"
        case .yellow:
            return "Amarillo"
        case .green:
            return "Verde"
        case .darkBlue:
            return "Azul oscuro"
        }
    }
}

enum BoardEventText {
    static func target(_ target: BoardEventTarget, in state: GameState) -> String {
        switch target {
        case let .side(side):
            let groups = ColorGroup.allCases.filter { $0.boardSide == side }.map(\.displayName)
            return "Lado \(side) (\(groups.joined(separator: " y ")))"
        case let .colorGroup(group):
            return "Grupo \(group.displayName)"
        case let .property(propertyID):
            return state.properties.first(where: { $0.id == propertyID })?.name ?? "Una propiedad"
        case .wholeBoard:
            return "Todo el tablero"
        case .allPlayers:
            return "Todos los jugadores"
        }
    }

    static func effect(_ effect: BoardEventEffect) -> String {
        switch effect {
        case let .rent(flat, percent, rounds):
            var change: [String] = []
            if percent != 0 {
                change.append("\(percent > 0 ? "+" : "−")\(abs(percent))%")
            }
            if flat != 0 {
                change.append("\(flat > 0 ? "+" : "−")$\(abs(flat))")
            }
            let duration = rounds == 1 ? "durante 1 ronda" : "durante \(rounds) rondas"
            return "Renta \(change.joined(separator: " y ")) \(duration)"
        case let .chargeShareholders(perProperty):
            return "$\(perProperty) por cada propiedad con dueño, repartidos entre sus accionistas"
        case let .payShareholders(perProperty):
            return "El banco paga $\(perProperty) por cada propiedad con dueño, repartidos entre sus accionistas"
        case let .payEveryPlayer(amount):
            return "Cada jugador cobra $\(amount) del banco"
        case let .chargeEveryPlayer(amount):
            return "Cada jugador paga $\(amount) al banco (o lo que tenga)"
        case .levelDown:
            return "La propiedad baja un nivel, sin reembolso"
        case .levelUp:
            return "La propiedad sube un nivel gratis"
        }
    }

    /// The event or host card that left `effect`, with its emoji.
    static func source(of effect: ActiveRentEffect) -> String? {
        if let event = BoardEventCatalog.event(withID: effect.eventID) {
            return "\(event.emoji) \(event.title)"
        }
        return HostCard(rawValue: effect.eventID).map { "\($0.emoji) \($0.title)" }
    }

    static func rentChange(_ effect: ActiveRentEffect) -> String {
        var change: [String] = []
        if effect.percent != 0 {
            change.append("\(effect.percent > 0 ? "+" : "−")\(abs(effect.percent))%")
        }
        if effect.flat != 0 {
            change.append("\(effect.flat > 0 ? "+" : "−")$\(abs(effect.flat))")
        }
        return change.joined(separator: " ")
    }

    static func remaining(_ effect: ActiveRentEffect, round: Int) -> String {
        guard let lastRound = effect.lastRound else {
            return "Permanente"
        }
        let rounds = max(0, lastRound - round + 1)
        return rounds == 1 ? "Última ronda" : "\(rounds) rondas más"
    }

}

/// Announces a board event the moment it happens, on every device.
struct BoardEventSheet: View {
    let occurrence: BoardEventOccurrence
    let state: GameState

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let event = BoardEventCatalog.event(withID: occurrence.eventID) {
            VStack(spacing: 18) {
                Text("EVENTO EN EL TABLERO")
                    .font(.app(.caption, weight: .heavy))
                    .tracking(1.6)
                    .foregroundStyle(Lux.textSecondary)
                Text(event.emoji)
                    .font(.app(size: 72))
                Text(event.title)
                    .font(.app(.title, weight: .black))
                    .multilineTextAlignment(.center)
                Text(event.text)
                    .foregroundStyle(Lux.textSecondary)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 10) {
                    Label(BoardEventText.target(occurrence.target, in: state), systemImage: "mappin.and.ellipse")
                    Label(BoardEventText.effect(event.effect), systemImage: "sparkles")
                    if !affectedNames.isEmpty {
                        Label(affectedNames, systemImage: "house")
                            .font(.app(.footnote))
                            .foregroundStyle(Lux.textSecondary)
                    }
                }
                .font(.app(.subheadline, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Lux.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Button {
                    dismiss()
                } label: {
                    Text("Entendido")
                        .font(.app(.headline))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Lux.gold, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .foregroundStyle(Lux.textPrimary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Lux.background)
            .presentationDetents([.medium, .large])
            .sensoryFeedback(.warning, trigger: occurrence.sequence)
        }
    }

    private var affectedNames: String {
        guard case .property = occurrence.target else {
            return state.properties
                .filter { occurrence.propertyIDs.contains($0.id) }
                .map(\.name)
                .joined(separator: ", ")
        }
        return ""
    }
}

/// When the next board event comes and which was the last one. Their rent changes
/// are in `RentChangesCard`.
struct ActiveBoardEventsCard: View {
    let events: BoardEventsState
    let state: GameState

    var body: some View {
        BankCard(title: "Eventos del tablero") {
            HStack {
                Label("Próximo evento", systemImage: "hourglass")
                    .foregroundStyle(Lux.textSecondary)
                Spacer()
                Text(nextEventText)
                    .font(.app(.subheadline, weight: .semibold))
            }
            .font(.app(.subheadline))

            if let last = events.lastOccurrence, let event = BoardEventCatalog.event(withID: last.eventID) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Último: \(event.emoji) \(event.title)")
                    Spacer()
                    Text("Ronda \(last.round)")
                        .foregroundStyle(Lux.textSecondary)
                }
                .font(.app(.subheadline))
            }
        }
    }

    private var nextEventText: String {
        let window = events.upcomingEventWindow(from: state.round)
        var earliest = window.lowerBound
        var latest = window.upperBound
        var mayNotHappen = false
        if let roundLimit = state.monopolife?.roundLimit {
            if earliest >= roundLimit {
                return "No habrá más"
            }
            if latest >= roundLimit {
                latest = roundLimit - 1
                mayNotHappen = true
            }
        }
        earliest = min(earliest, latest)
        let text: String
        if earliest == latest && !mayNotHappen {
            text = earliest == state.round ? "Al terminar esta ronda" : "Al terminar la ronda \(earliest)"
        } else if earliest == latest {
            text = earliest == state.round ? "Esta ronda" : "Ronda \(earliest)"
        } else {
            text = earliest == state.round ? "Desde esta ronda hasta la \(latest)" : "Entre la ronda \(earliest) y la \(latest)"
        }
        return mayNotHappen ? "\(text) o ninguno" : text
    }
}
