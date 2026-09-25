import SwiftUI

/// The host's side of a game: its waiting room, then the board once it starts.
struct HostGameView: View {
    @ObservedObject var model: GameSessionModel

    var body: some View {
        if model.gameState != nil {
            GameBoardView(model: model)
        } else if let lobby = model.lobby {
            HostLobbyView(model: model, lobby: lobby)
        } else {
            ProgressView("Iniciando partida…")
        }
    }
}

private struct HostLobbyView: View {
    @ObservedObject var model: GameSessionModel
    let lobby: Lobby
    @State private var manualPlayerName = ""

    private var hostPlayerID: UUID? {
        model.ownPlayerID
    }

    var body: some View {
        lobbyList(lobby)
            .navigationTitle("Sala de espera")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    EditButton()
                }
            }
#endif
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
                Text("Préstamos desde el 50% de tu patrimonio (sube o baja según la confianza de la banca) con un 10% de interés, pagados en 1 a 5 cuotas (una por cada GO). Los plazos que no uses hasta 5 quedan como aplazamientos.")
            }

            Section {
                Toggle(isOn: lobbyToggle(\.freeParkingEnabled)) {
                    Label("Bote de Free Parking", systemImage: "parkingsign.circle")
                }
            } footer: {
                Text("Impuestos, viajes, el interés de la tarjeta y el de deshipotecar se acumulan en un bote que se lleva quien caiga en Free Parking.")
            }

            if lobby.gameMode == .classic {
                Section {
                    Toggle(isOn: lobbyToggle(\.hiddenLevelsEnabled)) {
                        Label("Niveles secretos", systemImage: "eye.slash")
                    }
                } footer: {
                    Text("Todos ven el dinero de los demás, pero solo ves el nivel de las propiedades en las que tienes acciones. La renta de las demás se descubre al pagarla.")
                }
            }

            boardEventsSection(lobby)

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

    private enum BoardEventTiming: Hashable {
        case off
        case fixed
        case random
    }

    private func boardEventTiming(_ lobby: Lobby) -> BoardEventTiming {
        guard let interval = lobby.boardEventInterval else {
            return .off
        }
        return (lobby.boardEventMaxInterval ?? interval) > interval ? .random : .fixed
    }

    private func boardEventsSection(_ lobby: Lobby) -> some View {
        let range = BoardEventsState.intervalRange
        let minimum = lobby.boardEventInterval ?? 3
        let maximum = max(minimum, lobby.boardEventMaxInterval ?? minimum)

        return Section {
            Picker(selection: Binding(
                get: { boardEventTiming(lobby) },
                set: { timing in
                    model.updateLobby { lobby in
                        switch timing {
                        case .off:
                            lobby.boardEventInterval = nil
                            lobby.boardEventMaxInterval = nil
                        case .fixed:
                            lobby.boardEventInterval = lobby.boardEventInterval ?? 3
                            lobby.boardEventMaxInterval = nil
                        case .random:
                            let low = min(lobby.boardEventInterval ?? 2, range.upperBound - 1)
                            lobby.boardEventInterval = low
                            lobby.boardEventMaxInterval = max(low + 1, min(low + 3, range.upperBound))
                        }
                    }
                }
            )) {
                Text("No").tag(BoardEventTiming.off)
                Text("Fijo").tag(BoardEventTiming.fixed)
                Text("Al azar").tag(BoardEventTiming.random)
            } label: {
                Label("Eventos del tablero", systemImage: "tornado")
            }
            .pickerStyle(.segmented)

            switch boardEventTiming(lobby) {
            case .off:
                EmptyView()
            case .fixed:
                Stepper(value: Binding(
                    get: { minimum },
                    set: { value in model.updateLobby { $0.boardEventInterval = value } }
                ), in: range) {
                    Text(minimum == 1 ? "Cada ronda" : "Cada \(minimum) rondas")
                }
            case .random:
                Stepper(value: Binding(
                    get: { minimum },
                    set: { value in model.updateLobby { $0.boardEventInterval = value } }
                ), in: range.lowerBound...(maximum - 1)) {
                    Text("Mínimo: \(minimum) \(minimum == 1 ? "ronda" : "rondas")")
                }
                Stepper(value: Binding(
                    get: { maximum },
                    set: { value in model.updateLobby { $0.boardEventMaxInterval = value } }
                ), in: (minimum + 1)...range.upperBound) {
                    Text("Máximo: \(maximum) rondas")
                }
            }
        } header: {
            Text("Eventos del tablero")
        } footer: {
            switch boardEventTiming(lobby) {
            case .off:
                Text("Sin eventos. Actívalos para que cada tantas rondas pase algo en el tablero: un tornado, un famoso que se muda al barrio, una crisis… Todos lo ven a la vez.")
            case .fixed:
                Text("Al terminar cada \(minimum == 1 ? "ronda" : "\(minimum) rondas") ocurre un evento al azar.")
            case .random:
                Text("Tras cada evento, el siguiente llega entre \(minimum) y \(maximum) rondas después, sin que nadie sepa cuándo exactamente.")
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
                    .font(.app(.caption))
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
                // The host's own name is the app-wide one, so the next game has it.
                if playerID == hostPlayerID {
                    AppSettings.playerName = name
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
        HostGameView(model: .hosting(playerName: "Brian"))
    }
}
