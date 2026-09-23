import SwiftUI

struct GameBoardView: View {
    @ObservedObject var model: GameSessionModel
    @State private var amountAction: AmountAction?
    @State private var isShowingRole = false

    var body: some View {
        Group {
            if let state = model.gameState, state.monopolife?.isFinished == true {
                FinalRankingView(state: state)
            } else if let state = model.gameState {
                List {
                    if model.role == .client, !model.isHostConnected {
                        Section {
                            Label {
                                Text("Se perdió la conexión con el host. Esperando a que vuelva a abrir la partida…")
                            } icon: {
                                ProgressView()
                            }
                        }
                    }

                    turnSection(state)

                    if let profile = model.localProfile {
                        HappinessSection(model: model, profile: profile, isShowingRole: $isShowingRole)
                    }

                    if let pending = model.localPendingLifeCard, model.presentedLifeCard == nil {
                        Section {
                            Button {
                                model.presentedLifeCard = pending
                            } label: {
                                Label("Tienes una Tarjeta de Vida por decidir", systemImage: "questionmark.circle.fill")
                                    .font(.headline)
                            }
                        }
                    }

                    if isLocalPlayerActive(in: state) {
                        Section {
                            if model.isMonopolife {
                                Button {
                                    model.drawLifeCard()
                                } label: {
                                    Label("Caí en Suerte / Caja de Comunidad", systemImage: "rectangle.stack.badge.person.crop")
                                }
                                .disabled(!model.isLocalPlayersTurn || model.localPendingLifeCard != nil)
                            }

                            Button {
                                amountAction = .tax
                            } label: {
                                Label("Pagar impuesto", systemImage: "arrow.down.circle")
                            }
                            .disabled(!model.isLocalPlayersTurn)

                            Button {
                                amountAction = .salary
                            } label: {
                                Label("Cobrar salario", systemImage: "arrow.up.circle")
                            }
                            .disabled(!model.isLocalPlayersTurn)

                            if model.areCreditCardsEnabled {
                                NavigationLink {
                                    CreditCardView(model: model)
                                } label: {
                                    Label("Tarjeta de crédito", systemImage: "creditcard")
                                }
                            }

                            NavigationLink {
                                TransferView(model: model)
                            } label: {
                                Label("Pagar a un jugador", systemImage: "arrow.right.circle")
                            }

                            NavigationLink {
                                PayWithQRView(model: model)
                            } label: {
                                Label("Pagar con QR", systemImage: "qrcode.viewfinder")
                            }

                            NavigationLink {
                                CollectWithQRView(model: model)
                            } label: {
                                Label("Cobrar con QR", systemImage: "qrcode")
                            }

                            NavigationLink {
                                MarketView(model: model)
                            } label: {
                                Label("Mercado", systemImage: "chart.line.uptrend.xyaxis")
                                    .badge(model.dealsAwaitingLocalPlayer.count)
                            }

                            NavigationLink {
                                BankruptcyView(model: model)
                            } label: {
                                Label("Declararme en bancarrota", systemImage: "exclamationmark.triangle")
                            }
                        } header: {
                            Text("Acciones del jugador")
                        } footer: {
                            if model.isMonopolife {
                                Text("En Monopolife no se usan las cartas físicas de Suerte ni de Caja de Comunidad: al caer ahí, saca una Tarjeta de Vida.")
                            } else if !model.isLocalPlayersTurn {
                                Text("Impuestos, salario, compras, rentas, subastas y préstamos se hacen en tu turno. Pagar a otros jugadores, negociar en el Mercado, hipotecar y construir se puede en cualquier momento.")
                            }
                        }
                    }

                    Section("Jugadores") {
                        ForEach(state.players) { player in
                            HStack {
                                VStack(alignment: .leading) {
                                    HStack(spacing: 6) {
                                        if player.id == state.currentPlayerID {
                                            Image(systemName: "arrowtriangle.right.fill")
                                                .font(.caption)
                                                .foregroundStyle(.tint)
                                                .accessibilityLabel("Turno actual")
                                        }
                                        Text(player.name)
                                            .strikethrough(player.status == .bankrupt)
                                    }
                                    if player.id == model.localPlayerID {
                                        Text("Este dispositivo")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    if player.status == .bankrupt {
                                        Text("Bancarrota")
                                            .font(.caption)
                                            .foregroundStyle(.red)
                                    }
                                    if player.creditCardDebt > 0 {
                                        Text("Deuda de tarjeta: \(currency(player.creditCardDebt))")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                    }
                                }
                                Spacer()
                                Text(currency(player.balance))
                                    .fontWeight(.semibold)
                            }
                            .opacity(player.status == .bankrupt ? 0.65 : 1)
                        }
                    }

                    Section("Propiedades") {
                        ForEach(state.properties) { property in
                            propertyRow(property, state: state)
                        }
                    }
                }
            } else {
                ProgressView("Cargando partida…")
            }
        }
        .navigationTitle("Partida")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .alert(
            "Acción rechazada",
            isPresented: Binding(
                get: { model.alertMessage != nil },
                set: { if !$0 { model.dismissAlert() } }
            )
        ) {
            Button("OK", role: .cancel) {
                model.dismissAlert()
            }
        } message: {
            Text(model.alertMessage ?? "Inténtalo de nuevo.")
        }
        .sheet(item: $amountAction) { action in
            switch action {
            case .tax:
                AmountInputView(title: action.title) { amount in
                    model.payTax(amount: amount)
                }
            case .salary:
                SalaryView(model: model)
            }
        }
        .proximityReceiverBanner(model: model)
        .monopolifeBanners(model: model)
        .sheet(isPresented: $isShowingRole) {
            if let role = model.localProfile?.role {
                RoleSheet(role: role)
            }
        }
        .sheet(item: $model.presentedLifeCard) { draw in
            LifeCardSheet(model: model, draw: draw)
        }
        .fullScreenCover(isPresented: Binding(
            get: { !model.pendingRoleReveals.isEmpty },
            set: { _ in }
        )) {
            RoleRevealView(model: model)
        }
    }

    @ViewBuilder
    private func propertyRow(_ property: Property, state: GameState) -> some View {
        HStack {
            NavigationLink {
                PropertyDetailView(propertyID: property.id, model: model)
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(property.name)
                            .font(.headline)
                        Spacer()
                        Text(currency(property.purchasePrice))
                            .fontWeight(.semibold)
                    }

                    Text(ownerName(for: property, state: state))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if property.ownerID == nil, isLocalPlayerActive(in: state), model.isLocalPlayersTurn {
                Button("Comprar") {
                    model.buy(propertyID: property.id)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func turnSection(_ state: GameState) -> some View {
        if let currentPlayer = model.currentPlayer {
            Section(roundTitle(state)) {
                if model.controllablePlayers.count > 1 {
                    Picker("Jugando como", selection: Binding(
                        get: { model.localPlayerID },
                        set: { playerID in
                            if let playerID {
                                model.selectPlayer(playerID)
                            }
                        }
                    )) {
                        ForEach(model.controllablePlayers) { player in
                            Text(player.name).tag(Optional(player.id))
                        }
                    }
                }

                if model.isLocalPlayersTurn {
                    Label("Es tu turno", systemImage: "person.fill.checkmark")
                        .font(.headline)
                    Button {
                        model.endTurn()
                    } label: {
                        Text("Terminar turno")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Label("Turno de \(currentPlayer.name)", systemImage: "hourglass")
                        .font(.headline)
                    if model.role == .host {
                        Button("Pasar el turno de \(currentPlayer.name)") {
                            model.skipTurn()
                        }
                    }
                }
            }
        }
    }

    private func roundTitle(_ state: GameState) -> String {
        guard let roundLimit = state.monopolife?.roundLimit else {
            return "Ronda \(state.round)"
        }
        return "Ronda \(state.round) de \(roundLimit)"
    }

    private func ownerName(for property: Property, state: GameState) -> String {
        guard property.isOwned else {
            return "Sin dueño"
        }
        return property.ownership.count > 1
            ? "Accionistas: \(state.ownershipSummary(of: property))"
            : "Dueño: \(state.ownershipSummary(of: property))"
    }

    private func isLocalPlayerActive(in state: GameState) -> Bool {
        guard let localPlayerID = model.localPlayerID else {
            return false
        }
        return state.players.first(where: { $0.id == localPlayerID })?.status == .active
    }

    private func currency(_ amount: Int) -> String {
        "$\(amount)"
    }
}

private enum AmountAction: String, Identifiable {
    case tax
    case salary

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tax:
            return "Pagar impuesto"
        case .salary:
            return "Cobrar salario"
        }
    }
}

extension LifeCardDraw: Identifiable {
    var id: Int { sequence }
}
