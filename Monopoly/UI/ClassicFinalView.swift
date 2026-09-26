import SwiftUI

/// End of a Classic game: the winner, why it ended and everyone's net worth
/// (GAME_RULES section 7).
struct ClassicFinalView: View {
    let state: GameState
    let result: ClassicResult

    @Environment(\.dismiss) private var dismiss

    private var winnerIDs: Set<UUID> {
        Set(result.winnerIDs)
    }

    /// Active players first, each group by net worth.
    private var ranking: [(player: Player, netWorth: Int)] {
        state.players
            .map { ($0, GameRules.netWorthOrBalance(of: $0.id, in: state)) }
            .sorted { first, second in
                let firstActive = first.0.status == .active
                let secondActive = second.0.status == .active
                if firstActive != secondActive {
                    return firstActive
                }
                return first.1 > second.1
            }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                podium

                VStack(spacing: 12) {
                    ForEach(Array(ranking.enumerated()), id: \.element.player.id) { index, entry in
                        rankingRow(position: index + 1, player: entry.player, netWorth: entry.netWorth)
                    }
                }

                Button {
                    dismiss()
                } label: {
                    Text("Volver al inicio")
                        .font(.app(.headline))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(20)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Fin de la partida")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }

    private var podium: some View {
        let names = result.winnerIDs.map(state.playerName)
        return VStack(spacing: 8) {
            Text("🏆")
                .font(.app(size: 64))
            Text(names.count > 1 ? "¡Empate!" : "¡Ganó \(names.first ?? "")!")
                .font(.app(.largeTitle, weight: .black))
                .multilineTextAlignment(.center)
            if names.count > 1 {
                Text(names.joined(separator: " y "))
                    .font(.app(.title3, weight: .semibold))
            }
            Text(reasonText)
                .font(.app(.headline))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 12)
    }

    private var reasonText: String {
        switch result.reason {
        case .netWorthGoal:
            let goal = state.endConditions.netWorthGoal.map { "$\($0)" } ?? "la meta"
            return "Llegó a \(goal) de patrimonio en la ronda \(result.round)."
        case .bankruptcies:
            let count = state.players.filter { $0.status == .bankrupt }.count
            return "Quebraron \(count) \(count == 1 ? "jugador" : "jugadores") en la ronda \(result.round): gana el mayor patrimonio."
        case .lastPlayerStanding:
            return "Fue el último en quedar sin quebrar, en la ronda \(result.round)."
        }
    }

    private func rankingRow(position: Int, player: Player, netWorth: Int) -> some View {
        let isBankrupt = player.status == .bankrupt
        return HStack(spacing: 12) {
            Text("\(position)")
                .font(.app(.headline).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(player.name)
                    .font(.app(.headline))
                Text(isBankrupt ? "En bancarrota" : "Efectivo $\(player.balance)")
                    .font(.app(.subheadline))
                    .foregroundStyle(isBankrupt ? .red : .secondary)
            }
            Spacer()
            if !isBankrupt {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("$\(netWorth)")
                        .font(.app(.title3, weight: .heavy))
                        .monospacedDigit()
                    Text("patrimonio")
                        .font(.app(.caption))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(winnerIDs.contains(player.id) ? Color.yellow : Color.secondary.opacity(0.2), lineWidth: 1.5)
        }
    }
}
