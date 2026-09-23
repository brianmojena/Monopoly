import SwiftUI

struct BankruptcyView: View {
    @ObservedObject var model: GameSessionModel
    @Environment(\.dismiss) private var dismiss

    @State private var amountText = ""
    @State private var creditorSelection = BankruptcyCreditorSelection.bank
    @State private var pendingDebt: Debt?

    var body: some View {
        Group {
            if let state = model.gameState,
               let localPlayerID = model.localPlayerID {
                Form {
                    Section("Deuda que no puedes cubrir") {
                        TextField("Monto", text: $amountText)
#if os(iOS)
                            .keyboardType(.numberPad)
#endif
                        Text("Indica el monto de la deuda antes de continuar. Se usará para confirmar la decisión; la intención de bancarrota solo necesita conocer al acreedor.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Section("Acreedor") {
                        Picker("Debo a", selection: $creditorSelection) {
                            Text("La banca").tag(BankruptcyCreditorSelection.bank)
                            ForEach(activePlayers(in: state, excluding: localPlayerID)) { player in
                                Text(player.name)
                                    .tag(BankruptcyCreditorSelection.player(player.id))
                            }
                        }
                    }

                    Section {
                        Button("Continuar") {
                            prepareConfirmation()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canContinue)
                    } footer: {
                        Text(model.isMonopolife
                            ? "Perderás tus activos y la mitad de tu felicidad, pero seguirás jugando con $\(LifeRoleValues.bankruptcyRescueBalance) de rescate."
                            : "La bancarrota es irreversible: perderás tus activos y quedarás eliminado de la partida.")
                    }
                }
            } else {
                ProgressView("Cargando partida…")
            }
        }
        .navigationTitle("Bancarrota")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .confirmationDialog(
            "¿Declararte en bancarrota?",
            isPresented: Binding(
                get: { pendingDebt != nil },
                set: { if !$0 { pendingDebt = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Declararme en bancarrota", role: .destructive) {
                guard let debt = pendingDebt else {
                    return
                }
                model.declareBankruptcy(creditor: debt.creditor)
                pendingDebt = nil
                dismiss()
            }
            Button("Cancelar", role: .cancel) {
                pendingDebt = nil
            }
        } message: {
            Text(confirmationMessage)
        }
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
    }

    private var canContinue: Bool {
        guard let amount = Int(amountText) else {
            return false
        }
        return amount >= 0
    }

    private var confirmationMessage: String {
        guard let pendingDebt else {
            return ""
        }
        return "Deuda declarada: $\(pendingDebt.amount). Acreedor: \(creditorName(for: pendingDebt.creditor)). Esta acción no se puede deshacer."
    }

    private func prepareConfirmation() {
        guard let amount = Int(amountText), amount >= 0 else {
            return
        }

        pendingDebt = Debt(amount: amount, creditor: creditor)
    }

    private var creditor: DebtCreditor {
        switch creditorSelection {
        case .bank:
            return .bank
        case let .player(playerID):
            return .player(playerID)
        }
    }

    private func creditorName(for creditor: DebtCreditor) -> String {
        guard let state = model.gameState else {
            return "La banca"
        }

        switch creditor {
        case .bank:
            return "La banca"
        case let .player(playerID):
            return state.players.first(where: { $0.id == playerID })?.name ?? "Jugador"
        }
    }

    private func activePlayers(in state: GameState, excluding playerID: UUID) -> [Player] {
        state.players.filter { $0.id != playerID && $0.status == .active }
    }
}

private enum BankruptcyCreditorSelection: Hashable {
    case bank
    case player(UUID)
}
