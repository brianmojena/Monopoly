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
            let duration = rounds.map { $0 == 1 ? "durante 1 ronda" : "durante \($0) rondas" } ?? "para siempre"
            return "Renta \(change.joined(separator: " y ")) \(duration)"
        case let .chargeShareholders(perProperty):
            return "$\(perProperty) por cada propiedad con dueño, repartidos entre sus accionistas"
        case let .payEveryPlayer(amount):
            return "Cada jugador cobra $\(amount) del banco"
        case .levelDown:
            return "La propiedad baja un nivel, sin reembolso"
        }
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

    /// The round at whose end the next event happens.
    static func nextEventRound(_ events: BoardEventsState, round: Int) -> Int {
        ((round + events.interval - 1) / events.interval) * events.interval
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

/// The rent changes in play and when the next event comes.
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

            ForEach(events.rentEffects) { effect in
                if let event = BoardEventCatalog.event(withID: effect.eventID) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(event.emoji)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(event.title) · Renta \(BoardEventText.rentChange(effect))")
                                .font(.app(.subheadline, weight: .semibold))
                            Text(affectedText(effect))
                                .font(.app(.caption))
                                .foregroundStyle(Lux.textSecondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Text(BoardEventText.remaining(effect, round: state.round))
                            .font(.app(.caption, weight: .semibold))
                            .foregroundStyle(effect.flat + effect.percent >= 0 ? Lux.up : Lux.down)
                    }
                }
            }
        }
    }

    private var nextEventText: String {
        let next = BoardEventText.nextEventRound(events, round: state.round)
        if let roundLimit = state.monopolife?.roundLimit, next >= roundLimit {
            return "No habrá más"
        }
        return next == state.round ? "Al terminar esta ronda" : "Al terminar la ronda \(next)"
    }

    private func affectedText(_ effect: ActiveRentEffect) -> String {
        if effect.propertyIDs.count == state.properties.count {
            return "Todo el tablero"
        }
        return state.properties
            .filter { effect.propertyIDs.contains($0.id) }
            .map(\.name)
            .joined(separator: ", ")
    }
}
