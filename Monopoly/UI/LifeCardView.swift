import SwiftUI

/// A Life Card as its drawer sees it: only the happiness for their own role, never
/// the other roles' values, which would give their role away.
struct LifeCardView: View {
    let card: LifeCard
    let role: LifeRole?
    /// False for a possession card when the player did not own the possession.
    var hadEffect = true
    var isPending = false
    var balance = 0
    var onDecision: ((Bool) -> Void)?

    @State private var isFaceUp = false

    private var delta: Int {
        role.map { card.happiness(for: $0) } ?? 0
    }

    var body: some View {
        ZStack {
            back
                .opacity(isFaceUp ? 0 : 1)
            front
                .opacity(isFaceUp ? 1 : 0)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        .rotation3DEffect(.degrees(isFaceUp ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .onAppear {
            withAnimation(.spring(duration: 0.7).delay(0.15)) {
                isFaceUp = true
            }
        }
    }

    private var back: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(LinearGradient(
                colors: [Color(red: 0.08, green: 0.32, blue: 0.22), Color(red: 0.18, green: 0.5, blue: 0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .overlay {
                VStack(spacing: 8) {
                    Text("😊")
                        .font(.app(size: 56))
                    Text("TARJETA DE VIDA")
                        .font(.app(.caption, weight: .heavy))
                        .tracking(1.6)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .frame(minHeight: 320)
    }

    private var front: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(kindTitle, systemImage: kindIcon)
                    .font(.app(.caption, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("TARJETA DE VIDA")
                    .font(.app(.caption2, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
            }

            Text(card.title)
                .font(.app(.title, weight: .black))
                .fixedSize(horizontal: false, vertical: true)
            if card.kind == .movement {
                Label(card.text, systemImage: "figure.walk")
                    .font(.app(.headline))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            } else {
                Text(card.text)
                    .font(.app(.body))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let possession = card.grantedPossession {
                Text("Obtienes: \(possession.emoji) \(possession.name)")
                    .font(.app(.subheadline, weight: .semibold))
            }

            Spacer(minLength: 0)

            if hadEffect {
                effectRow
            } else if let possession = card.requiredPossession {
                Text("No tienes \(possession.name.lowercased()) \(possession.emoji): te salvaste 😅")
                    .font(.app(.headline))
                    .foregroundStyle(.secondary)
            }

            if isPending, let onDecision {
                decisionButtons(onDecision)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 320, alignment: .topLeading)
        .background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke((role?.color ?? .accentColor).opacity(0.6), lineWidth: 2)
        }
        .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
    }

    private var effectRow: some View {
        HStack(alignment: .firstTextBaseline) {
            if let moneyText {
                Text(moneyText)
                    .font(.app(.headline))
            }
            Spacer()
            if let role {
                Text("\(happinessText(delta)) \(delta >= 0 ? "😊" : "😞")")
                    .font(.app(.title2, weight: .heavy))
                    .foregroundStyle(happinessColor(delta))
                    .accessibilityLabel("\(happinessText(delta)) de felicidad para \(role.definition.name)")
            }
        }
    }

    private func decisionButtons(_ onDecision: @escaping (Bool) -> Void) -> some View {
        VStack(spacing: 10) {
            Button {
                onDecision(true)
            } label: {
                Text("Aceptar ($\(card.cost), \(happinessText(delta)) \(delta >= 0 ? "😊" : "😞"))")
                    .font(.app(.headline))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(role?.color)
            .disabled(balance < card.cost)

            Button {
                onDecision(false)
            } label: {
                Text("Pasar")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            if balance < card.cost {
                Text("No te alcanza el dinero: solo puedes pasar.")
                    .font(.app(.footnote))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var moneyText: String? {
        switch card.money {
        case .none:
            return nil
        case let .collect(amount):
            return "Cobras $\(amount)"
        case let .pay(amount):
            return card.kind == .decision ? "Cuesta $\(amount)" : "Pagas $\(amount)"
        case let .collectPerOwnedProperty(each, maximum):
            return "$\(each) por propiedad (máx $\(maximum))"
        case let .collectFromEachOtherPlayer(amount):
            return "$\(amount) de cada jugador"
        }
    }

    private var kindTitle: String {
        switch card.kind {
        case .event:
            return "Evento"
        case .decision:
            return "Decisión"
        case .possession:
            return "Posesión"
        case .movement:
            return "Movimiento"
        }
    }

    private var kindIcon: String {
        switch card.kind {
        case .event:
            return "sparkles"
        case .decision:
            return "questionmark.circle"
        case .possession:
            return "shippingbox"
        case .movement:
            return "figure.walk"
        }
    }
}

/// Full-size presentation of the card this device's player just drew.
struct LifeCardSheet: View {
    @ObservedObject var model: GameSessionModel
    let draw: LifeCardDraw

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                if let card = LifeCards.card(withID: draw.cardID) {
                    LifeCardView(
                        card: card,
                        role: model.gameState?.monopolife?.profiles[draw.playerID]?.role,
                        hadEffect: draw.hadEffect,
                        isPending: isPending,
                        balance: balance,
                        onDecision: { accept in
                            model.resolveLifeCard(accept: accept)
                            dismiss()
                        }
                    )
                    .padding(20)
                }
            }
            .navigationTitle("Tarjeta de Vida")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                if !isPending {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Listo") {
                            dismiss()
                        }
                    }
                }
            }
        }
        .interactiveDismissDisabled(isPending)
    }

    private var isPending: Bool {
        model.gameState?.monopolife?.pendingLifeCard?.sequence == draw.sequence
    }

    private var balance: Int {
        model.gameState?.players.first(where: { $0.id == draw.playerID })?.balance ?? 0
    }
}
