import SwiftUI

struct SalaryView: View {
    @ObservedObject var model: GameSessionModel

    /// Passing GO pays the normal salary; landing right on it pays double.
    private enum SalaryOption: Hashable {
        case passed
        case landed
        case other
    }

    static let passingSalary = 200
    static let landingSalary = 400

    @Environment(\.dismiss) private var dismiss
    @State private var option = SalaryOption.passed
    @State private var amountText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Salario", selection: $option) {
                        Text(currency(Self.passingSalary)).tag(SalaryOption.passed)
                        Text(currency(Self.landingSalary)).tag(SalaryOption.landed)
                        Text("Otro").tag(SalaryOption.other)
                    }
                    .pickerStyle(.segmented)

                    if option == .other {
                        TextField("Monto", text: $amountText)
#if os(iOS)
                            .keyboardType(.numberPad)
#endif
                    }
                } header: {
                    Text("Salario de GO")
                } footer: {
                    Text("\(currency(Self.passingSalary)) al pasar por GO, \(currency(Self.landingSalary)) si caes justo en GO. \"Otro\" es para cualquier otro monto.")
                }

                if !loans.isEmpty {
                    Section {
                        ForEach(Array(loans.enumerated()), id: \.element.id) { index, loan in
                            installmentRow(loan, number: index + 1)
                        }
                    } header: {
                        Text("Cuotas de tarjeta")
                    } footer: {
                        Text("Se descuentan al cobrar: \(currency(totalDue)). Si no te alcanza, se cobra lo que tengas, el resto queda atrasado para el siguiente GO y cuenta como un fallo que baja la confianza de la banca.")
                    }
                }

                if let state = model.gameState, !playerLoans.isEmpty {
                    Section {
                        ForEach(playerLoans) { loan in
                            LabeledContent(
                                "A \(state.playerName(loan.lenderID))",
                                value: currency(loan.goPaymentDue)
                            )
                        }
                    } header: {
                        Text("Préstamos de jugadores")
                    } footer: {
                        Text("Se pagan después de las cuotas de tarjeta. Si no te alcanza, se paga lo que tengas y el resto sigue como deuda.")
                    }
                }
            }
            .navigationTitle("Cobrar salario")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirmar") {
                        confirm()
                    }
                    .disabled(amount == nil)
                }
            }
        }
    }

    private func installmentRow(_ loan: CreditCardLoan, number: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Préstamo \(number): cuota de \(currency(GameRules.creditCardInstallmentDue(for: loan)))")
            Text(CreditCardView.installmentDescription(loan))
                .font(.app(.caption))
                .foregroundStyle(.secondary)
        }
    }

    private var loans: [CreditCardLoan] {
        guard let localPlayerID = model.localPlayerID else {
            return []
        }
        return model.gameState?.players.first(where: { $0.id == localPlayerID })?.creditCardLoans ?? []
    }

    /// Loans from other players that take a payment at this GO.
    private var playerLoans: [PlayerLoan] {
        guard let localPlayerID = model.localPlayerID else {
            return []
        }
        return model.gameState?.playerLoans.filter { $0.borrowerID == localPlayerID && $0.goPaymentDue > 0 } ?? []
    }

    private var totalDue: Int {
        loans.reduce(0) { $0 + GameRules.creditCardInstallmentDue(for: $1) }
    }

    private var amount: Int? {
        switch option {
        case .passed:
            return Self.passingSalary
        case .landed:
            return Self.landingSalary
        case .other:
            guard let amount = Int(amountText), amount >= 0 else {
                return nil
            }
            return amount
        }
    }

    private func confirm() {
        guard let amount else {
            return
        }
        model.collectSalary(amount: amount)
        dismiss()
    }

    private func currency(_ amount: Int) -> String {
        "$\(amount)"
    }
}
