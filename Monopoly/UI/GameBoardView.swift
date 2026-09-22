import SwiftUI

struct GameBoardView: View {
    @ObservedObject var model: GameSessionModel
    @State private var amountAction: AmountAction?

    var body: some View {
        Group {
            if let state = model.gameState {
                List {
                    Section("Acciones libres") {
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
                    }

                    Section("Jugadores") {
                        ForEach(state.players) { player in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(player.name)
                                    if player.id == model.localPlayerID {
                                        Text("Este dispositivo")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text(currency(player.balance))
                                    .fontWeight(.semibold)
                            }
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
            AmountInputView(title: action.title) { amount in
                switch action {
                case .tax:
                    model.payTax(amount: amount)
                case .salary:
                    model.collectSalary(amount: amount)
                }
            }
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

            if property.ownerID == nil, model.localPlayerID != nil {
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
