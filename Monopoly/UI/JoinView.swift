import SwiftUI

struct JoinView: View {
    @StateObject private var model: GameSessionModel

    // Built inside the StateObject autoclosure so browsing only starts when this
    // screen is actually shown, not when the start screen renders.
    init() {
        _model = StateObject(wrappedValue: Self.makeModel())
    }

    private static func makeModel() -> GameSessionModel {
        let transport = MultipeerGameTransport(displayName: "Monopoly-\(UUID().uuidString.prefix(8))")
        let session = GameSession(transport: transport, role: .client)
        return GameSessionModel(session: session, role: .client)
    }

    var body: some View {
        Group {
            if model.joinedRoomID == nil {
                RoomBrowserView(model: model)
            } else {
                JoinedGameView(model: model)
            }
        }
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }
}

private struct RoomBrowserView: View {
    @ObservedObject var model: GameSessionModel
    @State private var name = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tu nombre")
                        .font(.app(.headline))
                    TextField("¿Cómo te llamas?", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)
                    Text("Para volver a una partida en curso, usa el mismo nombre que tenías.")
                        .font(.app(.footnote))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Salas cercanas")
                            .font(.app(.headline))
                        Spacer()
                        ProgressView()
                            .controlSize(.small)
                    }

                    if model.rooms.isEmpty {
                        emptyState
                    } else {
                        ForEach(model.rooms) { room in
                            RoomCard(room: room, canJoin: !trimmedName.isEmpty) {
                                model.join(room, name: trimmedName)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Unirse a partida")
        .animation(.default, value: model.rooms)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.app(.largeTitle))
                .foregroundStyle(.secondary)
            Text("Buscando salas…")
                .font(.app(.subheadline, weight: .semibold))
            Text("Pide al host que pulse \"Alojar partida\" y que estéis en la misma red Wi‑Fi o cerca con Bluetooth activado.")
                .font(.app(.footnote))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct RoomCard: View {
    let room: DiscoveredRoom
    let canJoin: Bool
    let onJoin: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: room.phase == .lobby ? "person.3.fill" : "dice.fill")
                .font(.app(.title2))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(room.phase == .lobby ? Color.accentColor : Color.green, in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.app(.headline))
                        .lineLimit(1)
                    Text(room.mode == .monopolife ? "Monopolife" : "Classic")
                        .font(.app(.caption2, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .foregroundStyle(room.mode == .monopolife ? Color.pink : Color.secondary)
                        .background(
                            (room.mode == .monopolife ? Color.pink : Color.secondary).opacity(0.14),
                            in: Capsule()
                        )
                }
                Text(playersText)
                    .font(.app(.subheadline))
                    .foregroundStyle(.secondary)
                Label(statusText, systemImage: room.phase == .lobby ? "hourglass" : "play.fill")
                    .font(.app(.caption, weight: .medium))
                    .foregroundStyle(room.phase == .lobby ? Color.accentColor : Color.green)
            }

            Spacer(minLength: 8)

            Button("Unirse", action: onJoin)
                .buttonStyle(.borderedProminent)
                .disabled(!canJoin)
        }
        .padding(14)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        room.name.isEmpty ? "Partida sin nombre" : "Partida de \(room.name)"
    }

    private var playersText: String {
        room.playerCount == 1 ? "1 jugador" : "\(room.playerCount) jugadores"
    }

    private var statusText: String {
        room.phase == .lobby ? "En sala de espera" : "En curso · Ronda \(room.round)"
    }
}

private struct JoinedGameView: View {
    @ObservedObject var model: GameSessionModel

    var body: some View {
        Group {
            if let state = model.gameState {
                if let localPlayerID = model.localPlayerID,
                   state.players.contains(where: { $0.id == localPlayerID }) {
                    GameBoardView(model: model)
                } else {
                    SelectPlayerView(model: model)
                        .navigationTitle("Selecciona tu jugador")
                }
            } else if let lobby = model.lobby {
                waitingRoom(lobby)
            } else {
                connectingView
            }
        }
    }

    private func waitingRoom(_ lobby: Lobby) -> some View {
        List {
            Section {
                Label("Esperando a que el host inicie la partida…", systemImage: "hourglass")
            }

            Section("Jugadores (\(lobby.players.count))") {
                ForEach(Array(lobby.players.enumerated()), id: \.element.id) { index, player in
                    HStack {
                        Text("\(index + 1).")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Text(player.name.isEmpty ? "Sin nombre" : player.name)
                        Spacer()
                        if player.id == model.localPlayerID {
                            Text("Tú")
                                .font(.app(.caption))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Reglas") {
                LabeledContent("Modo de juego", value: lobby.gameMode == .monopolife ? "Monopolife" : "Monopoly Classic")
                if lobby.gameMode == .monopolife {
                    LabeledContent("Rondas", value: "\(lobby.roundLimit)")
                }
                LabeledContent("Tarjetas de crédito", value: lobby.creditCardsEnabled ? "Sí" : "No")
                LabeledContent("Bote de Free Parking", value: lobby.freeParkingEnabled ? "Sí" : "No")
                LabeledContent("Eventos del tablero", value: lobby.boardEventInterval.map { "Cada \($0) rondas" } ?? "No")
                if lobby.gameMode == .classic {
                    LabeledContent("Niveles secretos", value: lobby.hiddenLevelsEnabled ? "Sí" : "No")
                }
                LabeledContent("Pagar acercando iPhones", value: lobby.proximityPaymentsEnabled ? "Sí" : "No")
            }

            Section {
                Button("Salir de la sala", role: .destructive) {
                    model.leaveRoom()
                }
            }
        }
        .navigationTitle("Sala de espera")
    }

    private var connectingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Conectando a la sala…")
                .font(.app(.headline))
            Button("Cancelar") {
                model.leaveRoom()
            }
            .buttonStyle(.bordered)
        }
        .padding(24)
        .navigationTitle("Unirse a partida")
    }
}

#Preview {
    NavigationStack {
        JoinView()
    }
}
