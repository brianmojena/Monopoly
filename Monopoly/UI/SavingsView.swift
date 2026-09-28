import SwiftUI

struct SavingsView: View {
    @ObservedObject var model: GameSessionModel

    @State private var variableText = ""
    @State private var fixedText = ""
    @State private var fixedTerms = FixedDeposit.termRange.upperBound

    var body: some View {
        Group {
            if let state = model.gameState,
               let localPlayerID = model.localPlayerID,
               let player = state.players.first(where: { $0.id == localPlayerID }) {
                let savable = GameRules.savableAmount(for: localPlayerID, in: state)
                Form {
                    Section {
                        LabeledContent("Efectivo", value: currency(player.balance))
                        LabeledContent("Puedes ahorrar", value: currency(savable))
                        LabeledContent("Ahorrado", value: currency(player.savings.total))
                        if !player.savings.isEmpty {
                            LabeledContent("Interés en el próximo GO", value: currency(nextGoInterest(player.savings)))
                        }
                    } header: {
                        Text("Tus ahorros")
                    } footer: {
                        if savable < player.balance {
                            Text("No puedes ahorrar dinero que debes: a tu efectivo se le resta lo que debes de la tarjeta y a otros jugadores.")
                        }
                    }

                    variableSection(player.savings, savable: savable)
                    fixedSection(savable: savable)

                    if !player.savings.fixedDeposits.isEmpty {
                        depositsSection(player.savings.fixedDeposits)
                    }
                }
            } else {
                ProgressView("Cargando partida…")
            }
        }
        .navigationTitle("Ahorros")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }

    /// "10% → 20% → 30% → 40% → 50%"
    static var variableSchedule: String {
        (0..<5).map { "\(GameRules.variableSavingsRate(streak: $0))%" }.joined(separator: " → ")
    }

    /// "20% → 35% → 50% → 65% → 80%"
    static var fixedSchedule: String {
        FixedDeposit.termRange.map { "\(GameRules.fixedSavingsRate(go: $0))%" }.joined(separator: " → ")
    }

    private func variableSection(_ savings: Savings, savable: Int) -> some View {
        let amount = amount(from: variableText)
        return Section {
            LabeledContent("Saldo", value: currency(savings.variableBalance))
            LabeledContent("Interés del próximo GO", value: "\(GameRules.variableSavingsRate(streak: savings.variableStreak))%")
            amountField(text: $variableText)
            HStack {
                Button("Meter") {
                    guard let amount else { return }
                    model.depositSavings(amount: amount)
                    variableText = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(amount.map { $0 > savable } ?? true)

                Spacer()

                Button("Sacar") {
                    guard let amount else { return }
                    model.withdrawSavings(amount: amount)
                    variableText = ""
                }
                .buttonStyle(.bordered)
                .disabled(amount.map { $0 > savings.variableBalance } ?? true)
            }
        } header: {
            Text("Cuenta variable")
        } footer: {
            Text("Metes y sacas cuando quieras. En cada GO te paga en efectivo un % de lo que tengas ahorrado: \(Self.variableSchedule), y se queda en \(GameRules.variableSavingsMaximumRate)%. Sacar dinero lo vuelve a \(GameRules.variableSavingsFirstRate)%.")
        }
    }

    private func fixedSection(savable: Int) -> some View {
        let amount = amount(from: fixedText)
        return Section {
            amountField(text: $fixedText)
            Stepper("\(fixedTerms) paso(s) por GO", value: $fixedTerms, in: FixedDeposit.termRange)
            Button("Abrir cuenta fija") {
                guard let amount else { return }
                model.openFixedDeposit(amount: amount, terms: fixedTerms)
                fixedText = ""
            }
            .buttonStyle(.borderedProminent)
            .disabled(amount.map { $0 > savable } ?? true)
        } header: {
            Text("Cuenta fija")
        } footer: {
            Text(fixedFooter(amount: amount))
        }
    }

    private func fixedFooter(amount: Int?) -> String {
        let rates = FixedDeposit.termRange.prefix(fixedTerms).map { "\(GameRules.fixedSavingsRate(go: $0))%" }
            .joined(separator: " → ")
        let base = "No puedes meter ni sacar dinero hasta que termine. En cada GO te paga en efectivo un % de lo depositado: \(rates). Al último GO te devuelve lo depositado."
        guard let amount else {
            return base
        }
        let interest = GameRules.fixedSavingsTotalInterest(amount: amount, terms: fixedTerms)
        return base + " Con \(currency(amount)) ganas \(currency(interest)) en total."
    }

    private func depositsSection(_ deposits: [FixedDeposit]) -> some View {
        Section("Cuentas fijas") {
            ForEach(Array(deposits.enumerated()), id: \.element.id) { index, deposit in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Cuenta fija \(index + 1)")
                            .font(.app(.headline))
                        Spacer()
                        Text(currency(deposit.amount))
                            .font(.app(.body, weight: .semibold))
                    }
                    Text("Próximo GO: \(GameRules.fixedSavingsRate(go: deposit.gosPaid + 1))% · \(currency(fixedInterest(deposit)))")
                        .font(.app(.subheadline))
                    Text(deposit.gosRemaining == 1
                         ? "Termina en el próximo GO y te devuelve lo depositado"
                         : "Faltan \(deposit.gosRemaining) de \(deposit.terms) pasos por GO")
                        .font(.app(.caption))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func fixedInterest(_ deposit: FixedDeposit) -> Int {
        deposit.amount * GameRules.fixedSavingsRate(go: deposit.gosPaid + 1) / 100
    }

    private func nextGoInterest(_ savings: Savings) -> Int {
        savings.variableBalance * GameRules.variableSavingsRate(streak: savings.variableStreak) / 100
            + savings.fixedDeposits.reduce(0) { $0 + fixedInterest($1) }
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
