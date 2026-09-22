import SwiftUI

struct GameBoardView: View {
    @ObservedObject var model: GameSessionModel

    var body: some View {
        Group {
            if let state = model.gameState {
                List {
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
    }

    @ViewBuilder
    private func propertyRow(_ property: Property, state: GameState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(property.name)
                    .font(.headline)
                Spacer()
                Text(currency(property.purchasePrice))
                    .fontWeight(.semibold)
            }

            HStack {
                Text(ownerName(for: property, state: state))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                if property.ownerID == nil, model.localPlayerID != nil {
                    Button("Comprar") {
                        model.buy(propertyID: property.id)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
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
