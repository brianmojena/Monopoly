import SwiftUI

/// One loan between players: its terms, and paying it early or forgiving it
/// (GAME_RULES section 4.9).
struct PlayerLoanView: View {
    let loanID: UUID
    @ObservedObject var model: GameSessionModel
    @Environment(\.dismiss) private var dismiss

    @State private var paymentText = ""
    @State private var isConfirmingForgiveness = false

    var body: some View {
        Group {
            if let state = model.gameState,
               let localPlayerID = model.localPlayerID,
               let loan = state.playerLoans.first(where: { $0.id == loanID }) {
                Form {
                    Section {
                        LabeledContent("Presta", value: state.playerName(loan.lenderID))
                        LabeledContent("Debe", value: state.playerName(loan.borrowerID))
                        LabeledContent("Prestado", value: currency(loan.principal))
                        LabeledContent("Falta por pagar", value: currency(loan.remainingDebt))
                            .font(.app(.body, weight: .semibold))
                    }

                    Section("Términos") {
                        ForEach(state.loanTerms(loan), id: \.self) { line in
                            Text(line)
                        }
                    }

                    if loan.borrowerID == localPlayerID {
                        paymentSection(loan: loan, state: state, localPlayerID: localPlayerID)
                    }
                    if loan.lenderID == localPlayerID {
                        Section {
                            Button("Perdonar la deuda", role: .destructive) {
                                isConfirmingForgiveness = true
                            }
                        } footer: {
                            Text("\(state.playerName(loan.borrowerID)) ya no te deberá los \(currency(loan.remainingDebt)) que faltan.")
                        }
                    }
                }
                .confirmationDialog(
                    "¿Perdonar \(currency(loan.remainingDebt))?",
                    isPresented: $isConfirmingForgiveness,
                    titleVisibility: .visible
                ) {
                    Button("Perdonar", role: .destructive) {
                        model.forgivePlayerLoan(loanID: loan.id)
                        dismiss()
                    }
                    Button("Cancelar", role: .cancel) {}
                }
            } else {
                ContentUnavailableView("Préstamo saldado", systemImage: "checkmark.seal", description: Text("Este préstamo ya no existe."))
            }
        }
        .navigationTitle("Préstamo")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }

    private func paymentSection(loan: PlayerLoan, state: GameState, localPlayerID: UUID) -> some View {
        let balance = state.players.first(where: { $0.id == localPlayerID })?.balance ?? 0
        let amount = Int(paymentText)
        return Section {
            TextField("Monto", text: $paymentText)
#if os(iOS)
                .keyboardType(.numberPad)
#endif
            Button("Pagar") {
                if let amount {
                    model.payPlayerLoan(loanID: loan.id, amount: amount)
                    paymentText = ""
                }
            }
            .disabled(amount.map { $0 <= 0 || $0 > loan.remainingDebt || $0 > balance } ?? true)

            Button("Pagar todo (\(currency(loan.remainingDebt)))") {
                model.payPlayerLoan(loanID: loan.id, amount: loan.remainingDebt)
            }
            .buttonStyle(.borderedProminent)
            .disabled(balance < loan.remainingDebt)
        } header: {
            Text("Pagar antes")
        } footer: {
            Text("Tienes \(currency(balance)).")
        }
    }

    private func currency(_ amount: Int) -> String {
        "$\(amount)"
    }
}
