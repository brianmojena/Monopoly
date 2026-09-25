import SwiftUI

/// The host resolves a physical card from the table (GAME_RULES section 8.5).
struct HostCardsView: View {
    @ObservedObject var model: GameSessionModel

    @Environment(\.dismiss) private var dismiss
    @State private var card: HostCard = .rentDropOnSide
    @State private var side = 1
    @State private var isPermanent = false
    @State private var rounds = 3
    @State private var playerID: UUID?
    @State private var propertyID: UUID?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Carta", selection: $card) {
                        ForEach(HostCard.allCases) { card in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(card.emoji) \(card.title)")
                                Text(card.text)
                                    .font(.app(.caption))
                                    .foregroundStyle(.secondary)
                            }
                            .tag(card)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("¿Qué carta salió?")
                }

                if card.changesRent {
                    Section {
                        Picker("Lado", selection: $side) {
                            ForEach(1...4, id: \.self) { side in
                                Text(BoardEventText.target(.side(side), in: state)).tag(side)
                            }
                        }
                        Toggle("Permanente", isOn: $isPermanent)
                        if !isPermanent {
                            Stepper(rounds == 1 ? "Durante 1 ronda" : "Durante \(rounds) rondas", value: $rounds, in: 1...20)
                        }
                    } header: {
                        Text(card == .rentShiftToSide ? "Lado que sube" : "Lado del tablero")
                    } footer: {
                        Text(rentFooter)
                    }
                } else {
                    Section {
                        Picker("Jugador", selection: $playerID) {
                            Text("Elegir").tag(UUID?.none)
                            ForEach(state.players.filter { $0.status == .active }) { player in
                                Text(player.name).tag(Optional(player.id))
                            }
                        }
                        Picker("Propiedad", selection: $propertyID) {
                            Text("Elegir").tag(UUID?.none)
                            ForEach(levelableProperties) { property in
                                Text(property.name).tag(Optional(property.id))
                            }
                        }
                    } footer: {
                        Text("El jugador mueve su ficha a esa propiedad en el tablero y la propiedad sube un nivel gratis. Solo valen propiedades con dueño, sin hipotecar y por debajo del nivel \(Property.maximumLevel).")
                    }
                }
            }
            .navigationTitle("Cartas del host")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Aplicar") {
                        model.playHostCard(play)
                        dismiss()
                    }
                    .disabled(!card.changesRent && (playerID == nil || propertyID == nil))
                }
            }
        }
    }

    private var state: GameState {
        model.gameState ?? GameState(players: [], properties: [])
    }

    private var levelableProperties: [Property] {
        state.properties.filter { $0.isOwned && !$0.isMortgaged && $0.constructionLevel < Property.maximumLevel }
    }

    private var play: HostCardPlay {
        card.changesRent
            ? HostCardPlay(card: card, side: side, rounds: isPermanent ? nil : rounds)
            : HostCardPlay(card: card, playerID: playerID, propertyID: propertyID)
    }

    private var rentFooter: String {
        let duration = isPermanent ? "el resto de la partida" : "esta ronda y las siguientes hasta completar \(rounds)"
        if card == .rentShiftToSide {
            let neighbors = BoardEventsState.neighbors(ofSide: side).map(String.init).joined(separator: " y ")
            return "Sube $\(HostCard.rentChange) el lado \(side) y baja $\(HostCard.rentChange) en los lados \(neighbors), durante \(duration). La renta nunca baja de $0."
        }
        return "Dura \(duration). La renta nunca baja de $0."
    }
}

enum HostCardText {
    /// What a played card did, in one line.
    static func summary(_ play: HostCardPlay, in state: GameState) -> String {
        switch play.card {
        case .rentDropOnSide, .rentRaiseOnSide, .rentShiftToSide:
            let side = BoardEventText.target(.side(play.side ?? 0), in: state)
            let duration = play.rounds.map { $0 == 1 ? "durante 1 ronda" : "durante \($0) rondas" } ?? "para siempre"
            switch play.card {
            case .rentDropOnSide:
                return "\(side): renta −$\(HostCard.rentChange) \(duration)"
            case .rentRaiseOnSide:
                return "\(side): renta +$\(HostCard.rentChange) \(duration)"
            default:
                let neighbors = BoardEventsState.neighbors(ofSide: play.side ?? 0).map(String.init).joined(separator: " y ")
                return "\(side): renta +$\(HostCard.rentChange); lados \(neighbors): −$\(HostCard.rentChange), \(duration)"
            }
        case .advanceAndLevelUp:
            let player = play.playerID.map(state.playerName) ?? "Un jugador"
            let property = state.properties.first { $0.id == play.propertyID }?.name ?? "una propiedad"
            return "\(player) avanza a \(property), que sube un nivel"
        }
    }
}

/// Announces a host card the moment it is played, on every device.
struct HostCardSheet: View {
    let occurrence: HostCardOccurrence
    let state: GameState

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Text("CARTA")
                .font(.app(.caption, weight: .heavy))
                .tracking(1.6)
                .foregroundStyle(Lux.textSecondary)
            Text(occurrence.play.card.emoji)
                .font(.app(size: 72))
            Text(occurrence.play.card.title)
                .font(.app(.title, weight: .black))
                .multilineTextAlignment(.center)
            Text(HostCardText.summary(occurrence.play, in: state))
                .font(.app(.subheadline, weight: .semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
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
        .presentationDetents([.medium])
        .sensoryFeedback(.warning, trigger: occurrence.sequence)
    }
}

/// The rent changes host cards left in play.
struct HostCardEffectsCard: View {
    let state: GameState

    var body: some View {
        BankCard(title: "Cartas en juego") {
            ForEach(state.hostCardRentEffects) { effect in
                if let card = HostCard(rawValue: effect.eventID) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(card.emoji)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(card.title) · Renta \(BoardEventText.rentChange(effect))")
                                .font(.app(.subheadline, weight: .semibold))
                            Text(affectedSides(effect))
                                .font(.app(.caption))
                                .foregroundStyle(Lux.textSecondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Text(BoardEventText.remaining(effect, round: state.round))
                            .font(.app(.caption, weight: .semibold))
                            .foregroundStyle(effect.flat >= 0 ? Lux.up : Lux.down)
                    }
                }
            }
        }
    }

    private func affectedSides(_ effect: ActiveRentEffect) -> String {
        let sides = Set(state.properties.filter { effect.propertyIDs.contains($0.id) }.map(\.colorGroup.boardSide))
        return sides.sorted().map { BoardEventText.target(.side($0), in: state) }.joined(separator: ", ")
    }
}
