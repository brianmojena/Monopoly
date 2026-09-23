import SwiftUI

struct AuctionView: View {
    let propertyID: UUID
    @ObservedObject var model: GameSessionModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPlayerID: UUID?
    @State private var amountText = ""
    @State private var bids: [AuctionBid] = []

    var body: some View {
        Group {
            if let state = model.gameState,
               let property = state.properties.first(where: { $0.id == propertyID }) {
                Form {
                    Section("Propiedad") {
                        LabeledContent("Nombre", value: property.name)
                        LabeledContent("Precio de compra", value: currency(property.purchasePrice))
                    }

                    Section("Añadir puja") {
                        Picker("Jugador", selection: $selectedPlayerID) {
                            Text("Selecciona un jugador").tag(Optional<UUID>.none)
                            ForEach(activePlayers(in: state)) { player in
                                Text(player.name).tag(Optional(player.id))
                            }
                        }

                        TextField("Monto", text: $amountText)
#if os(iOS)
                            .keyboardType(.numberPad)
#endif

                        Text("La puja debe ser mayor que \(currency(minimumNextBid)).")
                            .font(.app(.footnote))
                            .foregroundStyle(.secondary)

                        Button("Añadir puja") {
                            addBid()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canAddBid)
                    }

                    Section("Pujas acumuladas") {
                        if bids.isEmpty {
                            Text("Todavía no hay pujas.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(Array(bids.enumerated()), id: \.offset) { index, bid in
                                HStack {
                                    Text("\(index + 1). \(playerName(for: bid.playerID, in: state))")
                                    Spacer()
                                    Text(currency(bid.amount))
                                        .font(.app(.body, weight: .semibold))
                                }
                            }
                        }
                    }

                    Section {
                        Button("Cerrar subasta") {
                            closeAuction(with: bids)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(bids.isEmpty)

                        Button("Cerrar subasta sin pujas") {
                            closeAuction(with: [])
                        }
                        .buttonStyle(.bordered)
                    } footer: {
                        Text("Una subasta sin pujas deja la propiedad sin dueño.")
                    }
                }
            } else {
                ProgressView("Cargando subasta…")
            }
        }
        .navigationTitle("Subasta")
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
        .onAppear {
            if selectedPlayerID == nil {
                selectedPlayerID = model.localPlayerID
            }
        }
    }

    private var minimumNextBid: Int {
        bids.last?.amount ?? 0
    }

    private var canAddBid: Bool {
        guard selectedPlayerID != nil, let amount = Int(amountText) else {
            return false
        }
        return amount > minimumNextBid
    }

    private func addBid() {
        guard let selectedPlayerID,
              let amount = Int(amountText),
              amount > minimumNextBid else {
            return
        }

        bids.append(AuctionBid(playerID: selectedPlayerID, amount: amount))
        amountText = ""
    }

    private func closeAuction(with bids: [AuctionBid]) {
        model.resolveAuction(propertyID: propertyID, bids: bids)
        dismiss()
    }

    private func activePlayers(in state: GameState) -> [Player] {
        state.players.filter { $0.status == .active }
    }

    private func playerName(for playerID: UUID, in state: GameState) -> String {
        state.players.first(where: { $0.id == playerID })?.name ?? "Jugador"
    }

    private func currency(_ amount: Int) -> String {
        "$\(amount)"
    }
}
