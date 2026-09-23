import SwiftUI

struct HostSetupView: View {
    @StateObject private var model: GameSessionModel
    @State private var manualPlayerName = ""

    // SwiftUI builds this view as soon as the start screen renders; creating the
    // session inside the StateObject autoclosure defers advertising until the lobby
    // is actually shown, and does it only once.
    init() {
        _model = StateObject(wrappedValue: Self.makeModel())
    }

    private static func makeModel() -> GameSessionModel {
        let hostPlayer = LobbyPlayer(name: "", isHostControlled: true)
        let transport = MultipeerGameTransport(displayName: "Monopoly-\(UUID().uuidString.prefix(8))")
        let session = GameSession(
            transport: transport,
            role: .host,
            lobby: Lobby(players: [hostPlayer]),
            hostPlayerID: hostPlayer.id
        )
        return GameSessionModel(session: session, role: .host, localPlayerID: hostPlayer.id, store: GameStore.shared)
    }

    private var hostPlayerID: UUID? {
        model.ownPlayerID
    }

    var body: some View {
        // The board replaces the lobby in place: going back leaves the game (it stays
        // saved) instead of returning to a lobby that no longer exists.
        if model.gameState != nil {
            GameBoardView(model: model)
        } else if let lobby = model.lobby {
            lobbyList(lobby)
                .navigationTitle("Sala de espera")
#if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    EditButton()
                }
#endif
        } else {
            ProgressView("Iniciando partida…")
        }
    }

    private func lobbyList(_ lobby: Lobby) -> some View {
        List {
            Section("Tu nombre") {
                if let hostPlayerID {
                    TextField("Tu nombre", text: nameBinding(for: hostPlayerID))
                }
            }

            Section {
                ForEach(Array(lobby.players.enumerated()), id: \.element.id) { index, player in
                    playerRow(player, turn: index + 1)
                }
                .onMove { source, destination in
                    model.updateLobby { $0.players.move(fromOffsets: source, toOffset: destination) }
                }
                .onDelete { offsets in
                    model.updateLobby { lobby in
                        let removableIDs = offsets
                            .map { lobby.players[$0] }
                            .filter { $0.isHostControlled && $0.id != hostPlayerID }
                            .map(\.id)
                        lobby.players.removeAll { removableIDs.contains($0.id) }
                    }
                }

                HStack {
                    TextField("Jugador sin teléfono", text: $manualPlayerName)
                    Button("Añadir") {
                        addManualPlayer()
                    }
                    .disabled(manualPlayerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } header: {
                Text("Jugadores (\(lobby.players.count))")
            } footer: {
                Text("Los demás entran con \"Unirse a partida\" en su iPhone y escriben su nombre. Si alguien no tiene teléfono, añádelo aquí: jugará desde este iPhone. Pulsa Editar para ordenar los turnos o quitar jugadores sin teléfono.")
            }

            Section {
                Picker("Modo de juego", selection: Binding(
                    get: { lobby.gameMode },
                    set: { mode in model.updateLobby { $0.gameMode = mode } }
                )) {
                    Text("Monopoly Classic").tag(GameMode.classic)
                    Text("Monopolife").tag(GameMode.monopolife)
                }
                .pickerStyle(.segmented)

                if lobby.gameMode == .monopolife {
                    Picker("Rondas", selection: Binding(
                        get: { lobby.roundLimit },
                        set: { limit in model.updateLobby { $0.roundLimit = limit } }
                    )) {
                        ForEach(MonopolifeState.roundLimitOptions, id: \.self) { limit in
                            Text("\(limit)").tag(limit)
                        }
                    }
                }
            } header: {
                Text("Modo de juego")
            } footer: {
                Text(lobby.gameMode == .monopolife
                    ? "Gana quien tenga más felicidad al terminar la última ronda. Cada jugador recibe un rol secreto con una ruleta, y las cartas de Suerte y Caja de Comunidad se cambian por Tarjetas de Vida."
                    : "El Monopoly de siempre: gana quien no quiebre.")
            }

            Section {
                Toggle(isOn: lobbyToggle(\.creditCardsEnabled)) {
                    Label("Tarjetas de crédito", systemImage: "creditcard")
                }
            } header: {
                Text("Reglas")
            } footer: {
                Text("Préstamos de hasta el 50% de tu patrimonio con un 10% de interés, pagados en 1 a 5 cuotas (una por cada GO). Los plazos que no uses hasta 5 quedan como aplazamientos.")
            }

            Section {
                Toggle(isOn: lobbyToggle(\.proximityPaymentsEnabled)) {
                    Label("Pagar acercando iPhones", systemImage: "wave.3.right")
                }
            } header: {
                Text("Pagos")
            } footer: {
                Text("Opcional. Los pagos normales siguen disponibles; esto añade la opción de pagar acercando tu iPhone al de otro jugador (UWB, iPhone 11 o posterior, excepto SE).")
            }

            Section {
                Button("Iniciar partida") {
                    model.startGame()
                }
                .disabled(!lobby.canStart)
            } footer: {
                Text("Hacen falta de \(Lobby.playerLimit.lowerBound) a \(Lobby.playerLimit.upperBound) jugadores, todos con nombre. El saldo inicial de $\(GameSessionModel.placeholderInitialBalance) es un placeholder.")
            }
        }
    }

    private func playerRow(_ player: LobbyPlayer, turn: Int) -> some View {
        HStack {
            Text("\(turn).")
                .foregroundStyle(.secondary)
                .monospacedDigit()
            VStack(alignment: .leading) {
                Text(player.name.isEmpty ? "Sin nombre" : player.name)
                    .foregroundStyle(player.name.isEmpty ? .secondary : .primary)
                Text(playerDescription(player))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .deleteDisabled(!player.isHostControlled || player.id == hostPlayerID)
    }

    private func playerDescription(_ player: LobbyPlayer) -> String {
        if player.id == hostPlayerID {
            return "Tú (host)"
        }
        return player.isHostControlled ? "Sin teléfono · juega en este iPhone" : "Conectado desde su iPhone"
    }

    private func nameBinding(for playerID: UUID) -> Binding<String> {
        Binding(
            get: { model.lobby?.players.first(where: { $0.id == playerID })?.name ?? "" },
            set: { name in
                model.updateLobby { lobby in
                    guard let index = lobby.players.firstIndex(where: { $0.id == playerID }) else {
                        return
                    }
                    lobby.players[index].name = name
                }
            }
        )
    }

    private func lobbyToggle(_ keyPath: WritableKeyPath<Lobby, Bool>) -> Binding<Bool> {
        Binding(
            get: { model.lobby?[keyPath: keyPath] ?? false },
            set: { value in
                model.updateLobby { $0[keyPath: keyPath] = value }
            }
        )
    }

    private func addManualPlayer() {
        let name = manualPlayerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            return
        }
        model.updateLobby { $0.players.append(LobbyPlayer(name: name, isHostControlled: true)) }
        manualPlayerName = ""
    }
}

#Preview {
    NavigationStack {
        HostSetupView()
    }
}
