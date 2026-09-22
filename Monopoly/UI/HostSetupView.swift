import SwiftUI

struct HostSetupView: View {
    @State private var playerNames = ["Jugador 1"]
    @State private var hostPlayerIndex = 0
    @State private var proximityPaymentsEnabled = false
    @State private var gameModel: GameSessionModel?
    @State private var isGameStarted = false

    private var canStart: Bool {
        playerNames.count >= 2 && playerNames.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        List {
            Section {
                ForEach(Array(playerNames.enumerated()), id: \.offset) { index, _ in
                    HStack {
                        TextField(
                            "Nombre del jugador",
                            text: Binding(
                                get: { playerNames[index] },
                                set: { playerNames[index] = $0 }
                            )
                        )

                        Button {
                            removePlayer(at: index)
                        } label: {
                            Image(systemName: "minus.circle")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Quitar jugador")
                    }
                }

                Button {
                    playerNames.append("Jugador \(playerNames.count + 1)")
                } label: {
                    Label("Añadir jugador", systemImage: "plus.circle")
                }
            } header: {
                Text("Jugadores")
            } footer: {
                Text("Añade al menos dos jugadores, incluido tú.")
            }

            Section("Este dispositivo") {
                Picker("Mi jugador", selection: $hostPlayerIndex) {
                    ForEach(playerNames.indices, id: \.self) { index in
                        Text(playerNames[index].isEmpty ? "Sin nombre" : playerNames[index])
                            .tag(index)
                    }
                }
            }

            Section {
                Toggle(isOn: $proximityPaymentsEnabled) {
                    Label("Pagar acercando iPhones", systemImage: "wave.3.right")
                }
            } header: {
                Text("Pagos")
            } footer: {
                Text("Opcional. Los pagos normales siguen disponibles; esto añade la opción de pagar acercando tu iPhone al de otro jugador (UWB, iPhone 11 o posterior, excepto SE).")
            }

            Section {
                Button("Iniciar partida") {
                    startGame()
                }
                .disabled(!canStart)
            } footer: {
                Text("El saldo inicial de $\(GameSessionModel.placeholderInitialBalance) es un placeholder para este walking skeleton.")
            }
        }
        .navigationTitle("Alojar partida")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .navigationDestination(isPresented: $isGameStarted) {
            gameDestination
        }
    }

    @ViewBuilder
    private var gameDestination: some View {
        if let gameModel {
            GameBoardView(model: gameModel)
        } else {
            EmptyView()
        }
    }

    private func removePlayer(at index: Int) {
        guard playerNames.count > 1 else {
            return
        }

        playerNames.remove(at: index)
        hostPlayerIndex = min(hostPlayerIndex, playerNames.count - 1)
    }

    private func startGame() {
        guard canStart else {
            return
        }

        let players = playerNames.map { name in
            Player(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                balance: GameSessionModel.placeholderInitialBalance
            )
        }
        let initialState = GameState(
            players: players,
            properties: PlaceholderProperties.all,
            proximityPaymentsEnabled: proximityPaymentsEnabled
        )
        let transport = MultipeerGameTransport(displayName: "Monopoly-\(UUID().uuidString.prefix(8))")
        let session = GameSession(transport: transport, role: .host, initialState: initialState)
        gameModel = GameSessionModel(
            session: session,
            role: .host,
            localPlayerID: players[hostPlayerIndex].id
        )
        isGameStarted = true
    }
}

#Preview {
    NavigationStack {
        HostSetupView()
    }
}
