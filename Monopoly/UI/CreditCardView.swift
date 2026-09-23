import SwiftUI

struct CreditCardView: View {
    @ObservedObject var model: GameSessionModel

    @State private var loanText = ""
    @State private var installments = 1
    @State private var selectedLoanID: UUID?
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
                        if !player.creditCardLoans.isEmpty {
                            LabeledContent("Cuotas en el próximo GO", value: currency(nextGoTotal(for: player)))
                        }
                    }

                    loanSection(availableCredit: availableCredit)

                    if !player.creditCardLoans.isEmpty {
                        loansSection(player.creditCardLoans)
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

            Picker("Plazos", selection: $installments) {
                ForEach(1...GameRules.maxCreditCardInstallments, id: \.self) { count in
                    Text("\(count)").tag(count)
                }
            }
            .pickerStyle(.segmented)

            Button("Pedir préstamo") {
                guard let amount = amount(from: loanText) else {
                    return
                }
                model.borrowOnCreditCard(amount: amount, installments: installments)
                loanText = ""
            }
            .buttonStyle(.borderedProminent)
            .disabled(amount(from: loanText).map { $0 > availableCredit } ?? true)
        } header: {
            Text("Pedir préstamo")
        } footer: {
            Text(loanFooter)
        }
    }

    private var loanFooter: String {
        let postponements = GameRules.maxCreditCardInstallments - installments
        let postponementsText = postponements == 1 ? "1 aplazamiento" : "\(postponements) aplazamientos"
        guard let amount = amount(from: loanText) else {
            return "Hasta el 50% de tu patrimonio (efectivo + propiedades no hipotecadas + construcciones − deuda), menos lo que ya debes. 10% de interés. Con \(installments) plazo(s) tienes \(postponementsText)."
        }
        let debt = GameRules.creditCardDebt(forLoan: amount)
        let firstInstallment = GameRules.creditCardInstallmentDue(for: CreditCardLoan(
            remainingDebt: debt,
            installmentsRemaining: installments,
            postponementsRemaining: postponements
        ))
        return "Recibes \(currency(amount)) y debes \(currency(debt)) (10% de interés) en \(installments) cuota(s) de \(currency(firstInstallment)), una en cada GO. Tienes \(postponementsText)."
    }

    private func loansSection(_ loans: [CreditCardLoan]) -> some View {
        Section("Préstamos") {
            ForEach(Array(loans.enumerated()), id: \.element.id) { index, loan in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Préstamo \(index + 1)")
                            .font(.headline)
                        Spacer()
                        Text(currency(loan.remainingDebt))
                            .fontWeight(.semibold)
                    }
                    Text("\(loan.installmentsRemaining) cuota(s) restante(s) de \(currency(GameRules.creditCardInstallmentDue(for: loan)))")
                        .font(.subheadline)
                    Text("Aplazamientos disponibles: \(loan.postponementsRemaining)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func paymentSection(player: Player) -> some View {
        let loans = player.creditCardLoans
        let loan = loans.first(where: { $0.id == selectedLoanID }) ?? loans[0]

        return Section {
            if loans.count > 1 {
                Picker("Préstamo", selection: Binding(
                    get: { loan.id },
                    set: { selectedLoanID = $0 }
                )) {
                    ForEach(Array(loans.enumerated()), id: \.element.id) { index, loan in
                        Text("Préstamo \(index + 1) · \(currency(loan.remainingDebt))").tag(loan.id)
                    }
                }
            }

            amountField(text: $paymentText)

            Button("Pagar") {
                guard let amount = amount(from: paymentText) else {
                    return
                }
                model.payCreditCard(loanID: loan.id, amount: amount)
                paymentText = ""
            }
            .buttonStyle(.borderedProminent)
            .disabled(amount(from: paymentText).map { $0 > loan.remainingDebt } ?? true)

            Button("Liquidar préstamo (\(currency(loan.remainingDebt)))") {
                model.payCreditCard(loanID: loan.id, amount: loan.remainingDebt)
            }
            .disabled(player.balance < loan.remainingDebt)
        } header: {
            Text("Adelantar pago")
        } footer: {
            Text("Un pago adelantado reduce las cuotas que quedan del préstamo. En cada GO se cobra una cuota de cada préstamo; puedes aplazarla al cobrar el salario si te quedan aplazamientos.")
        }
    }

    private func nextGoTotal(for player: Player) -> Int {
        player.creditCardLoans.reduce(0) { $0 + GameRules.creditCardInstallmentDue(for: $1) }
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
