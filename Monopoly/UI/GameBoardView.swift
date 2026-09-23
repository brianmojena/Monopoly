import SwiftUI

struct GameBoardView: View {
    @ObservedObject var model: GameSessionModel
    @State private var amountAction: AmountAction?

    var body: some View {
        Group {
            if let state = model.gameState {
                List {
                    if isLocalPlayerActive(in: state) {
                        Section("Acciones del jugador") {
                            Button {
                                amountAction = .tax
                            } label: {
                                Label("Pagar impuesto", systemImage: "arrow.down.circle")
                            }

                            Button {
                                amountAction = .salary
                            } label: {
                                Label("Cobrar salario", systemImage: "arrow.up.circle")
                            }

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
                                TradeView(model: model)
                            } label: {
                                Label("Proponer intercambio", systemImage: "arrow.left.arrow.right")
                            }

                            NavigationLink {
                                BankruptcyView(model: model)
                            } label: {
                                Label("Declararme en bancarrota", systemImage: "exclamationmark.triangle")
                            }
                        }
                    }

                    Section("Jugadores") {
                        ForEach(state.players) { player in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(player.name)
                                        .strikethrough(player.status == .bankrupt)
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

            if property.ownerID == nil, isLocalPlayerActive(in: state) {
                Button("Comprar") {
                    model.buy(propertyID: property.id)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }

    private func ownerName(for property: Property, state: GameState) -> String {
        guard let ownerID = property.ownerID,
              let owner = state.players.first(where: { $0.id == ownerID }) else {
            return "Sin dueño"
        }
        return "Dueño: \(owner.name)"
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
