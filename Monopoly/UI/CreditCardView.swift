import SwiftUI

struct CreditCardView: View {
    @ObservedObject var model: GameSessionModel

    @State private var loanText = ""
    @State private var paymentText = ""

    var body: some View {
        Group {
            if let state = model.gameState,
               let localPlayerID = model.localPlayerID,
               let player = state.players.first(where: { $0.id == localPlayerID }) {
                let availableCredit = (try? GameRules.availableCredit(for: localPlayerID, in: state)) ?? 0
                Form {
                    Section("Tu tarjeta") {
                        LabeledContent("Efectivo", value: currency(player.balance))
                        LabeledContent("Patrimonio", value: currency((try? GameRules.netWorth(of: localPlayerID, in: state)) ?? 0))
                        LabeledContent("Deuda", value: currency(player.creditCardDebt))
                        LabeledContent("Crédito disponible", value: currency(availableCredit))
                        if player.creditCardDebt > 0 {
                            LabeledContent(
                                "Pago mínimo en GO",
                                value: currency(GameRules.creditCardMinimumPayment(forDebt: player.creditCardDebt))
                            )
                        }
                    }

                    loanSection(availableCredit: availableCredit)

                    if player.creditCardDebt > 0 {
                        paymentSection(player: player)
                    }
                }
            } else {
                ProgressView("Cargando partida…")
            }
        }
        .navigationTitle("Tarjeta de crédito")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .proximityReceiverBanner(model: model)
    }

    private func loanSection(availableCredit: Int) -> some View {
        Section {
            amountField(text: $loanText)

            Button("Pedir préstamo") {
                guard let amount = amount(from: loanText) else {
                    return
                }
                model.borrowOnCreditCard(amount: amount)
                loanText = ""
            }
            .buttonStyle(.borderedProminent)
            .disabled(amount(from: loanText).map { $0 > availableCredit } ?? true)
        } header: {
            Text("Pedir préstamo")
        } footer: {
            if let amount = amount(from: loanText) {
                Text("Recibes \(currency(amount)) y tu deuda aumenta \(currency(GameRules.creditCardDebt(forLoan: amount))) (10% de interés).")
            } else {
                Text("Hasta el 50% de tu patrimonio (efectivo + propiedades no hipotecadas + construcciones − deuda), menos lo que ya debes. Se cobra un 10% de interés al pedirlo.")
            }
        }
    }

    private func paymentSection(player: Player) -> some View {
        Section {
            amountField(text: $paymentText)

            Button("Pagar") {
                guard let amount = amount(from: paymentText) else {
                    return
                }
                model.payCreditCard(amount: amount)
                paymentText = ""
            }
            .buttonStyle(.borderedProminent)
            .disabled(amount(from: paymentText).map { $0 > player.creditCardDebt } ?? true)

            Button("Pagar toda la deuda (\(currency(player.creditCardDebt)))") {
                model.payCreditCard(amount: player.creditCardDebt)
            }
            .disabled(player.balance < player.creditCardDebt)
        } header: {
            Text("Pagar deuda")
        } footer: {
            Text("Puedes adelantar pagos cuando quieras. Al cobrar el salario de GO se descuenta automáticamente el 25% de la deuda; si no te alcanza, se cobra lo que tengas y el resto sigue como deuda.")
        }
    }

    private func amountField(text: Binding<String>) -> some View {
        TextField("Monto", text: text)
#if os(iOS)
            .keyboardType(.numberPad)
#endif
    }

    private func amount(from text: String) -> Int? {
        guard let amount = Int(text), amount > 0 else {
            return nil
        }
        return amount
    }

    private func currency(_ amount: Int) -> String {
        "$\(amount)"
    }
}
