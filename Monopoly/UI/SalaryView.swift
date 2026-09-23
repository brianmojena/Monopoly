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
    @State private var postponedLoanIDs = Set<UUID>()

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
                        Text("Se descuentan al cobrar: \(currency(totalDue)). Si no te alcanza, se cobra lo que tengas, el resto queda pendiente para el siguiente GO y cuenta como un fallo que baja la confianza de la banca. Aplazar una cuota la mueve al final, sin recargo y sin fallo.")
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
        Toggle(isOn: postponeBinding(for: loan.id)) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Préstamo \(number): cuota de \(currency(GameRules.creditCardInstallmentDue(for: loan)))")
                Text(postponementsDescription(loan.postponementsRemaining))
                    .font(.app(.caption))
                    .foregroundStyle(.secondary)
            }
        }
        .disabled(loan.postponementsRemaining == 0)
    }

    private var loans: [CreditCardLoan] {
        guard let localPlayerID = model.localPlayerID else {
            return []
        }
        return model.gameState?.players.first(where: { $0.id == localPlayerID })?.creditCardLoans ?? []
    }

    private var totalDue: Int {
        loans
            .filter { !postponedLoanIDs.contains($0.id) }
            .reduce(0) { $0 + GameRules.creditCardInstallmentDue(for: $1) }
    }

    private func postponeBinding(for loanID: UUID) -> Binding<Bool> {
        Binding(
            get: { postponedLoanIDs.contains(loanID) },
            set: { isPostponed in
                if isPostponed {
                    postponedLoanIDs.insert(loanID)
                } else {
                    postponedLoanIDs.remove(loanID)
                }
            }
        )
    }

    private func postponementsDescription(_ count: Int) -> String {
        switch count {
        case 0:
            return "Aplazar · no te quedan aplazamientos"
        case 1:
            return "Aplazar · te queda 1 aplazamiento"
        default:
            return "Aplazar · te quedan \(count) aplazamientos"
        }
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
        let validPostponements = postponedLoanIDs.intersection(loans.map(\.id))
        model.collectSalary(amount: amount, postponedLoanIDs: validPostponements)
        dismiss()
    }

    private func currency(_ amount: Int) -> String {
        "$\(amount)"
    }
}
