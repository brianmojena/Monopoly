import SwiftUI

struct TransferView: View {
    @ObservedObject var model: GameSessionModel
    /// Called instead of dismissing this screen once the payment is sent.
    var onPaid: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    @State private var recipientID: UUID?
    @State private var amountText = ""

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
                }
            } else {
                ProgressView("Cargando partida…")
            }
        }
        .navigationTitle("Pagar a un jugador")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
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
        finish()
    }

    private func finish() {
        if let onPaid {
            onPaid()
        } else {
            dismiss()
        }
    }

    private func activePlayers(in state: GameState, excluding playerID: UUID) -> [Player] {
        state.players.filter { $0.id != playerID && $0.status == .active }
    }
}
