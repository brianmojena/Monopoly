import SwiftUI

/// The Monopolife summary on the board: only the local player's happiness, role and
/// possessions, never anyone else's.
struct HappinessSection: View {
    @ObservedObject var model: GameSessionModel
    let profile: LifeProfile
    @Binding var isShowingRole: Bool

    var body: some View {
        BankCard {
            HStack(spacing: 16) {
                Text(profile.role.definition.emoji)
                    .font(.system(size: 40))
                    .frame(width: 60, height: 60)
                    .background(profile.role.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 2) {
                    Text("TU FELICIDAD")
                        .font(.caption2.weight(.semibold))
                        .tracking(1.2)
                        .foregroundStyle(Lux.textSecondary)
                    Text("\(profile.happiness) 😊")
                        .font(.system(.largeTitle, design: .rounded, weight: .black))
                        .contentTransition(.numericText(value: Double(profile.happiness)))
                        .animation(.spring, value: profile.happiness)
                }

                Spacer()

                if !profile.possessions.isEmpty {
                    Text(profile.possessions.sorted(by: { $0.rawValue < $1.rawValue }).map(\.emoji).joined(separator: " "))
                        .font(.title2)
                        .accessibilityLabel("Posesiones: \(profile.possessions.map(\.name).joined(separator: ", "))")
                }
            }
            .accessibilityElement(children: .combine)

            HStack(spacing: 10) {
                Button {
                    isShowingRole = true
                } label: {
                    Label("Mi rol", systemImage: "theatermasks")
                        .frame(maxWidth: .infinity)
                }

                NavigationLink {
                    HappinessHistoryView(model: model)
                } label: {
                    Label("Historial", systemImage: "list.bullet.rectangle")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
            .tint(Lux.gold)

            Text("Tu rol y tu felicidad son secretos. Gana quien tenga más felicidad al terminar la última ronda.")
                .font(.caption)
                .foregroundStyle(Lux.textSecondary)
        }
    }
}

struct HappinessHistoryView: View {
    @ObservedObject var model: GameSessionModel

    var body: some View {
        List {
            if rounds.isEmpty {
                ContentUnavailableView(
                    "Aún sin cambios",
                    systemImage: "face.smiling",
                    description: Text("Aquí verás cada vez que tu felicidad suba o baje.")
                )
            }
            ForEach(rounds, id: \.self) { round in
                Section("Ronda \(round)") {
                    ForEach(Array(events(in: round).enumerated()), id: \.offset) { _, event in
                        HStack {
                            Text(event.reason.title)
                            Spacer()
                            Text(happinessText(event.delta))
                                .fontWeight(.bold)
                                .foregroundStyle(happinessColor(event.delta))
                        }
                    }
                }
            }
        }
        .navigationTitle("Mi felicidad")
    }

    private var localEvents: [HappinessEvent] {
        (model.gameState?.monopolife?.happinessLog ?? []).filter { $0.playerID == model.localPlayerID }
    }

    private var rounds: [Int] {
        Array(Set(localEvents.map(\.round))).sorted(by: >)
    }

    private func events(in round: Int) -> [HappinessEvent] {
        localEvents.filter { $0.round == round }.reversed()
    }
}

/// Brief happiness changes and other players' Life Card draws, shown over the board.
struct MonopolifeBanners: ViewModifier {
    @ObservedObject var model: GameSessionModel

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                VStack(spacing: 8) {
                    if let toast = model.happinessToasts.first {
                        banner(
                            text: "\(happinessText(toast.event.delta)) \(toast.event.delta >= 0 ? "😊" : "😞")  \(toast.event.reason.title)",
                            color: happinessColor(toast.event.delta)
                        )
                        .id(toast.id)
                        .task(id: toast.id) {
                            try? await Task.sleep(for: .seconds(2.4))
                            withAnimation {
                                model.dismissHappinessToast(toast)
                            }
                        }
                    }

                    if let notice = model.lifeCardNotice, let text = noticeText(notice) {
                        banner(text: text, color: .accentColor)
                            .id(notice.sequence)
                            .task(id: notice.sequence) {
                                try? await Task.sleep(for: .seconds(3))
                                withAnimation {
                                    model.dismissLifeCardNotice()
                                }
                            }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .animation(.spring(duration: 0.4), value: model.happinessToasts.first?.id)
                .animation(.spring(duration: 0.4), value: model.lifeCardNotice?.sequence)
            }
    }

    private func banner(text: String, color: Color) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
            .overlay {
                Capsule().stroke(color.opacity(0.6), lineWidth: 1.5)
            }
            .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
            .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func noticeText(_ draw: LifeCardDraw) -> String? {
        guard let name = model.gameState?.players.first(where: { $0.id == draw.playerID })?.name,
              let card = LifeCards.card(withID: draw.cardID) else {
            return nil
        }
        return "\(name) sacó una Tarjeta de Vida: \(card.title)"
    }
}

extension View {
    func monopolifeBanners(model: GameSessionModel) -> some View {
        modifier(MonopolifeBanners(model: model))
    }
}
