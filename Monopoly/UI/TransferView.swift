import SwiftUI

struct TransferView: View {
    @ObservedObject var model: GameSessionModel
    @Environment(\.dismiss) private var dismiss

    @State private var recipientID: UUID?
    @State private var amountText = ""
    @State private var proximityPayment: ProximityPayment?
    @State private var didPayByProximity = false

    var body: some View {
        Group {
            if let state = model.gameState,
               let localPlayerID = model.localPlayerID {
                Form {
                    Section("Monto") {
                        TextField("Monto", text: $amountText)
#if os(iOS)
                            .keyboardType(.numberPad)
#endif
                    }

                    Section {
                        Picker("Pagar a", selection: $recipientID) {
                            Text("Selecciona un jugador").tag(Optional<UUID>.none)
                            ForEach(activePlayers(in: state, excluding: localPlayerID)) { player in
                                Text(player.name).tag(Optional(player.id))
                            }
                        }

                        Button("Pagar") {
                            payManually()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(amount == nil || recipientID == nil)
                    } footer: {
                        Text("Para cartas de Suerte o Caja de Comunidad que obligan a pagar a otro jugador.")
                    }

                    if model.isProximityPaymentEnabled {
                        Section {
                            Button {
                                if let amount {
                                    proximityPayment = .transfer(amount: amount)
                                }
                            } label: {
                                Label("Pagar acercando iPhones", systemImage: "wave.3.right")
                            }
                            .disabled(amount == nil)
                        } header: {
                            Text("Acercando iPhones")
                        } footer: {
                            Text("Opcional: acerca tu iPhone al del jugador que cobra y se identificará solo, sin elegirlo en la lista.")
                        }
                    }
                }
            } else {
                ProgressView("Cargando partida…")
            }
        }
        .navigationTitle("Pagar a un jugador")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .sheet(item: $proximityPayment, onDismiss: {
            if didPayByProximity {
                dismiss()
            }
        }) { payment in
            ProximityPaymentView(payment: payment, model: model) {
                didPayByProximity = true
            }
        }
        .proximityReceiverBanner(model: model)
    }

    private var amount: Int? {
        guard let amount = Int(amountText), amount > 0 else {
            return nil
        }
        return amount
    }

    private func payManually() {
        guard let amount, let recipientID else {
            return
        }
        model.transfer(to: recipientID, amount: amount)
        dismiss()
    }

    private func activePlayers(in state: GameState, excluding playerID: UUID) -> [Player] {
        state.players.filter { $0.id != playerID && $0.status == .active }
    }
}
