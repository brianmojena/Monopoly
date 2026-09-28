import SwiftUI

struct CreditCardView: View {
    @ObservedObject var model: GameSessionModel

    @State private var loanText = ""
    @State private var selectedLoanID: UUID?

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

                    trustSection(player.creditHistory)

                    loanSection(player: player, availableCredit: availableCredit)

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
    }

    private func trustSection(_ history: CreditHistory) -> some View {
        Section {
            LabeledContent("Límite", value: GameRules.isCreditCut(for: history)
                ? "Sin crédito"
                : "\(GameRules.creditLimitPercentage(for: history))% del patrimonio")
            LabeledContent("Préstamos pagados", value: "\(history.paidOffLoans)")
            LabeledContent("Fallos", value: "\(history.missedPayments) de \(GameRules.missedPaymentsBeforeCreditIsCut)")
                .foregroundStyle(history.missedPayments > 0 ? .red : .primary)
            LabeledContent("Préstamos a la vez", value: "\(GameRules.maximumSimultaneousLoans(for: history))")
        } header: {
            Text("Confianza de la banca")
        } footer: {
            Text("Cada préstamo que terminas de pagar sube tu límite \(GameRules.creditTrustStepPercentage) puntos (máx. \(GameRules.maximumCreditLimitPercentage)%) y te deja tener dos préstamos a la vez. Cada GO en que no cubres una cuota lo baja \(GameRules.creditTrustStepPercentage) puntos; con \(GameRules.missedPaymentsBeforeCreditIsCut) fallos ya no puedes pedir crédito.")
        }
    }

    private func loanSection(player: Player, availableCredit: Int) -> some View {
        let history = player.creditHistory
        let isCut = GameRules.isCreditCut(for: history)
        let maximumLoans = GameRules.maximumSimultaneousLoans(for: history)
        let isAtLoanLimit = player.creditCardLoans.count >= maximumLoans
        return Section {
            amountField(text: $loanText)

            Button("Pedir préstamo") {
                guard let amount = amount(from: loanText) else {
                    return
                }
                model.borrowOnCreditCard(amount: amount)
                loanText = ""
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                !model.isLocalPlayersTurn
                    || isCut
                    || isAtLoanLimit
                    || (amount(from: loanText).map { $0 > availableCredit } ?? true)
            )
        } header: {
            Text("Pedir préstamo")
        } footer: {
            if isCut {
                Text("La banca ya no te da crédito: fallaste \(GameRules.missedPaymentsBeforeCreditIsCut) pagos.")
            } else if isAtLoanLimit {
                Text(maximumLoans == 1
                     ? "Solo puedes tener un préstamo a la vez hasta que termines de pagar uno."
                     : "Ya tienes \(maximumLoans) préstamos, el máximo a la vez.")
            } else {
                Text(model.isLocalPlayersTurn ? loanFooter(history) : "Los préstamos se piden en tu turno. " + loanFooter(history))
            }
        }
    }

    private func loanFooter(_ history: CreditHistory) -> String {
        let rates = Self.interestSchedule
        guard let amount = amount(from: loanText) else {
            return "Hasta el \(GameRules.creditLimitPercentage(for: history))% de tu patrimonio (efectivo + propiedades no hipotecadas + construcciones − deuda), menos lo que ya debes. Se paga en \(GameRules.creditCardInstallments) plazos, uno en cada GO, con interés \(rates)."
        }
        let firstInstallment = GameRules.creditCardInstallmentDue(for: CreditCardLoan(principal: amount))
        return "Recibes \(currency(amount)) y lo pagas en \(GameRules.creditCardInstallments) plazos, uno en cada GO. El interés sube con cada GO: \(rates). La primera cuota es de \(currency(firstInstallment)). Cuanto antes pagues, menos interés."
    }

    /// "10% → 15% → 20% → 25% → 40%"
    static var interestSchedule: String {
        GameRules.creditCardInterestPercentages.map { "\($0)%" }.joined(separator: " → ")
    }

    static func installmentDescription(_ loan: CreditCardLoan) -> String {
        let rate = GameRules.creditCardInterestPercentage(installment: loan.currentInstallment)
        let installment = min(loan.currentInstallment, GameRules.creditCardInstallments)
        var text = loan.installmentsRemaining > 0
            ? "Plazo \(installment) de \(GameRules.creditCardInstallments) · \(rate)% de interés · \(loan.installmentsRemaining) cuota(s) por pagar"
            : "Sin cuotas por pagar"
        if loan.overdueDebt > 0 {
            text += " · $\(loan.overdueDebt) atrasado"
        }
        return text
    }

    private func loansSection(_ loans: [CreditCardLoan]) -> some View {
        Section("Préstamos") {
            ForEach(Array(loans.enumerated()), id: \.element.id) { index, loan in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Préstamo \(index + 1)")
                            .font(.app(.headline))
                        Spacer()
                        Text(currency(loan.remainingDebt))
                            .font(.app(.body, weight: .semibold))
                    }
                    Text("Próxima cuota: \(currency(GameRules.creditCardInstallmentDue(for: loan)))")
                        .font(.app(.subheadline))
                    Text(Self.installmentDescription(loan))
                        .font(.app(.caption))
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

            let installmentDue = GameRules.creditCardInstallmentDue(for: loan)
            if installmentDue < loan.remainingDebt {
                Button("Pagar una cuota (\(currency(installmentDue)))") {
                    model.payCreditCard(loanID: loan.id, paysOff: false)
                }
                .buttonStyle(.borderedProminent)
                .disabled(player.balance < installmentDue)
            }

            Button("Liquidar préstamo (\(currency(loan.remainingDebt)))") {
                model.payCreditCard(loanID: loan.id, paysOff: true)
            }
            .disabled(player.balance < loan.remainingDebt)
        } header: {
            Text("Adelantar pago")
        } footer: {
            Text("Pagar una cuota ahora cobra el interés del plazo en curso y el préstamo termina antes. Liquidar paga todo lo que falta con el interés del plazo en curso. El interés sube con cada GO: \(Self.interestSchedule).")
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
