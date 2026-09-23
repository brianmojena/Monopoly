import SwiftUI

struct JoinView: View {
    @State private var name = ""
    @State private var model: GameSessionModel?

    var body: some View {
        Group {
            if let model {
                JoinedGameView(model: model)
            } else {
                nameForm
            }
        }
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }

    private var nameForm: some View {
        Form {
            Section {
                TextField("Tu nombre", text: $name)
                    .submitLabel(.join)
                    .onSubmit(join)
            } header: {
                Text("¿Cómo te llamas?")
            } footer: {
                Text("Así aparecerás en la sala de espera y en la partida.")
            }

            Section {
                Button("Buscar partida") {
                    join()
                }
                .disabled(trimmedName.isEmpty)
            }
        }
        .navigationTitle("Unirse a partida")
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func join() {
        guard !trimmedName.isEmpty else {
            return
        }

        let player = LobbyPlayer(name: trimmedName, isHostControlled: false)
        let transport = MultipeerGameTransport(displayName: "Monopoly-\(UUID().uuidString.prefix(8))")
        let session = GameSession(transport: transport, role: .client, lobbyPlayer: player)
        model = GameSessionModel(session: session, role: .client, localPlayerID: player.id)
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
                searchingView
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
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Reglas") {
                LabeledContent("Tarjetas de crédito", value: lobby.creditCardsEnabled ? "Sí" : "No")
                LabeledContent("Pagar acercando iPhones", value: lobby.proximityPaymentsEnabled ? "Sí" : "No")
            }
        }
        .navigationTitle("Sala de espera")
    }

    private var searchingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Buscando partida…")
                .font(.headline)
            Text("Asegúrate de que el host ya abrió la sala de espera y que ambos dispositivos están en la misma red local.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
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
