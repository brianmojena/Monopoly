import SwiftUI

/// End of a Monopolife game: every role, happiness and possession is revealed.
struct FinalRankingView: View {
    let state: GameState

    @Environment(\.dismiss) private var dismiss
    @State private var expandedPlayerID: UUID?

    private var monopolife: MonopolifeState? {
        state.monopolife
    }

    private var winnerIDs: Set<UUID> {
        Set(GameRules.winners(in: state))
    }

    private var ranking: [(player: Player, profile: LifeProfile)] {
        state.players
            .compactMap { player in monopolife?.profiles[player.id].map { (player, $0) } }
            .sorted { first, second in
                if first.profile.happiness != second.profile.happiness {
                    return first.profile.happiness > second.profile.happiness
                }
                return netWorth(of: first.player) > netWorth(of: second.player)
            }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                podium

                VStack(spacing: 12) {
                    ForEach(Array(ranking.enumerated()), id: \.element.player.id) { index, entry in
                        rankingRow(position: index + 1, player: entry.player, profile: entry.profile)
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
        let winners = ranking.filter { winnerIDs.contains($0.player.id) }
        return VStack(spacing: 8) {
            Text("🏆")
                .font(.app(size: 64))
            Text(winners.count > 1 ? "¡Empate!" : "¡Ganó \(winners.first?.player.name ?? "")!")
                .font(.app(.largeTitle, weight: .black))
                .multilineTextAlignment(.center)
            if winners.count > 1 {
                Text(winners.map(\.player.name).joined(separator: " y "))
                    .font(.app(.title3, weight: .semibold))
            }
            if let happiness = winners.first?.profile.happiness {
                Text("\(happiness) 😊 de felicidad")
                    .font(.app(.headline))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 12)
    }

    private func rankingRow(position: Int, player: Player, profile: LifeProfile) -> some View {
        let isExpanded = expandedPlayerID == player.id
        return VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.snappy) {
                    expandedPlayerID = isExpanded ? nil : player.id
                }
            } label: {
                HStack(spacing: 12) {
                    Text("\(position)")
                        .font(.app(.headline).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 22)
                    Text(profile.role.definition.emoji)
                        .font(.app(.title))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.name)
                            .font(.app(.headline))
                        Text(profile.role.definition.name)
                            .font(.app(.subheadline, weight: .semibold))
                            .foregroundStyle(profile.role.color)
                    }
                    Spacer()
                    Text("\(profile.happiness) 😊")
                        .font(.app(.title3, weight: .heavy))
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                breakdown(for: player.id, profile: profile)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(winnerIDs.contains(player.id) ? Color.yellow : profile.role.color.opacity(0.3), lineWidth: 1.5)
        }
    }

    private func breakdown(for playerID: UUID, profile: LifeProfile) -> some View {
        let events = (monopolife?.happinessLog ?? []).filter { $0.playerID == playerID }
        let totals = Dictionary(grouping: events, by: \.reason.breakdownTitle)
            .mapValues { $0.reduce(0) { $0 + $1.delta } }
            .sorted { $0.value > $1.value }

        return VStack(alignment: .leading, spacing: 6) {
            if totals.isEmpty {
                Text("Sin cambios de felicidad.")
                    .foregroundStyle(.secondary)
            }
            ForEach(totals, id: \.key) { title, total in
                HStack {
                    Text(title)
                    Spacer()
                    Text(happinessText(total))
                        .font(.app(.body, weight: .bold))
                        .foregroundStyle(happinessColor(total))
                }
                .font(.app(.subheadline))
            }
            if !profile.possessions.isEmpty {
                Divider()
                Text("Posesiones: " + profile.possessions.sorted(by: { $0.rawValue < $1.rawValue })
                    .map { "\($0.emoji) \($0.name)" }
                    .joined(separator: ", "))
                    .font(.app(.subheadline))
            }
        }
        .padding(.leading, 34)
    }

    private func netWorth(of player: Player) -> Int {
        (try? GameRules.netWorth(of: player.id, in: state)) ?? player.balance
    }
}
