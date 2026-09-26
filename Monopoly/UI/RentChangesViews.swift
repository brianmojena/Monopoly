import SwiftUI

/// The rent changes in play from board events and host cards, summed per part of the
/// board so it never grows past a few rows. "Ver detalle" lists every effect.
struct RentChangesCard: View {
    let state: GameState

    @State private var isShowingDetail = false

    var body: some View {
        let summary = GameRules.rentChangeSummary(in: state)
        let effectCount = GameRules.activeRentEffects(in: state).count
        BankCard(title: "Rentas modificadas") {
            if summary.isEmpty {
                Text("Los cambios se compensan: ninguna renta cambia ahora.")
                    .font(.app(.subheadline))
                    .foregroundStyle(Lux.textSecondary)
            }
            ForEach(Array(summary.enumerated()), id: \.offset) { _, group in
                row(group)
            }
            Button {
                isShowingDetail = true
            } label: {
                HStack {
                    Text(effectCount == 1 ? "Ver detalle" : "Ver detalle (\(effectCount) efectos)")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.app(.caption, weight: .bold))
                }
                .font(.app(.footnote, weight: .semibold))
                .foregroundStyle(Lux.gold)
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $isShowingDetail) {
            RentChangesDetailView(state: state)
        }
    }

    private func row(_ group: RentChangeGroup) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(RentChangeText.title(group.scope, in: state))
                    .font(.app(.subheadline, weight: .semibold))
                Text(RentChangeText.subtitle(group, in: state))
                    .font(.app(.caption))
                    .foregroundStyle(Lux.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(RentChangeText.change(percent: group.percent, flat: group.flat))
                    .font(.app(.subheadline, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(group.percent + group.flat >= 0 ? Lux.up : Lux.down)
                Text(RentChangeText.duration(group.effects, round: state.round))
                    .font(.app(.caption))
                    .foregroundStyle(Lux.textSecondary)
            }
        }
    }
}

/// Every board event and host card changing rent right now, with where it applies and
/// how long it lasts.
struct RentChangesDetailView: View {
    let state: GameState

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(GameRules.activeRentEffects(in: state)) { effect in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(BoardEventText.source(of: effect) ?? "Efecto")
                            .font(.app(.subheadline, weight: .semibold))
                        Text(affectedText(effect))
                            .font(.app(.caption))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Renta \(BoardEventText.rentChange(effect))")
                            .font(.app(.subheadline, weight: .bold))
                            .foregroundStyle(effect.percent + effect.flat >= 0 ? .green : .red)
                        Text(BoardEventText.remaining(effect, round: state.round))
                            .font(.app(.caption))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Rentas modificadas")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
        }
    }

    /// The board sides an effect covers when it covers them whole, else its properties.
    private func affectedText(_ effect: ActiveRentEffect) -> String {
        if effect.propertyIDs.count == state.properties.count {
            return "Todo el tablero"
        }
        var parts: [String] = []
        for side in 1...4 {
            let sideProperties = state.properties.filter { $0.colorGroup.boardSide == side }
            let covered = sideProperties.filter { effect.propertyIDs.contains($0.id) }
            if !covered.isEmpty, covered.count == sideProperties.count {
                parts.append("Lado \(side)")
            } else {
                parts += covered.map(\.name)
            }
        }
        return parts.joined(separator: ", ")
    }
}

enum RentChangeText {
    static func title(_ scope: BoardEventTarget, in state: GameState) -> String {
        switch scope {
        case let .side(side):
            return "Lado \(side)"
        case let .colorGroup(group):
            return "Grupo \(group.displayName)"
        case let .property(propertyID):
            return state.propertyName(propertyID)
        case .wholeBoard, .allPlayers:
            return "Todo el tablero"
        }
    }

    static func subtitle(_ group: RentChangeGroup, in state: GameState) -> String {
        let place: String?
        switch group.scope {
        case let .side(side):
            place = ColorGroup.allCases.filter { $0.boardSide == side }.map(\.displayName).joined(separator: " y ")
        case let .colorGroup(colorGroup):
            place = "Lado \(colorGroup.boardSide)"
        case let .property(propertyID):
            place = state.properties.first(where: { $0.id == propertyID }).map { "Grupo \($0.colorGroup.displayName)" }
        case .wholeBoard, .allPlayers:
            place = nil
        }
        let sources = group.effects.count == 1
            ? BoardEventText.source(of: group.effects[0])
            : "\(group.effects.count) efectos"
        return [place, sources].compactMap { $0 }.joined(separator: " · ")
    }

    static func change(percent: Int, flat: Int) -> String {
        var parts: [String] = []
        if percent != 0 {
            parts.append("\(percent > 0 ? "+" : "−")\(abs(percent))%")
        }
        if flat != 0 {
            parts.append("\(flat > 0 ? "+" : "−")$\(abs(flat))")
        }
        return parts.joined(separator: " ")
    }

    /// When the soonest of the effects ends, or "Permanente" if none does.
    static func duration(_ effects: [ActiveRentEffect], round: Int) -> String {
        guard let soonest = effects.filter({ $0.lastRound != nil }).min(by: { $0.lastRound! < $1.lastRound! }) else {
            return "Permanente"
        }
        if effects.count == 1 {
            return BoardEventText.remaining(soonest, round: round)
        }
        let rounds = max(0, (soonest.lastRound ?? round) - round + 1)
        return rounds == 1 ? "Cambia tras esta ronda" : "Cambia en \(rounds) rondas"
    }
}
