import SwiftUI

/// Who is in jail and for how many turns, on every device (GAME_RULES section 5). The
/// jailed player taps their own row, on their turn, to get out.
struct JailCard: View {
    let state: GameState
    @ObservedObject var model: GameSessionModel
    @Binding var isChoosingExit: Bool

    var body: some View {
        BankCard(title: "En la cárcel") {
            ForEach(state.players.filter { $0.status == .active && $0.isInJail }) { player in
                if player.id == model.localPlayerID {
                    Button {
                        isChoosingExit = true
                    } label: {
                        row(player, actionText: model.isLocalPlayersTurn ? "Salir" : "Sales en tu turno")
                    }
                    .buttonStyle(.plain)
                    .disabled(!model.isLocalPlayersTurn)
                } else {
                    row(player, actionText: nil)
                }
            }
        }
    }

    private func row(_ player: Player, actionText: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("🚔")
            VStack(alignment: .leading, spacing: 2) {
                Text(player.name)
                    .font(.app(.subheadline, weight: .semibold))
                Text(JailText.turn(player.jailTurn ?? 0))
                    .font(.app(.caption))
                    .foregroundStyle(Lux.textSecondary)
            }
            Spacer()
            if let actionText {
                Text(actionText)
                    .font(.app(.caption, weight: .semibold))
                    .foregroundStyle(Lux.gold)
            }
        }
    }
}

enum JailText {
    static func turn(_ turn: Int) -> String {
        switch turn {
        case 0:
            return "Acaba de entrar"
        case GameRules.maximumJailTurns...:
            return "Turno \(turn) de \(GameRules.maximumJailTurns) · sale solo en su próximo turno"
        default:
            return "Turno \(turn) de \(GameRules.maximumJailTurns) en la cárcel"
        }
    }
}

extension View {
    /// The two ways out of jail: rolled doubles, or pay the fine to the pot.
    func jailExitDialog(isPresented: Binding<Bool>, model: GameSessionModel) -> some View {
        confirmationDialog("¿Cómo sales de la cárcel?", isPresented: isPresented, titleVisibility: .visible) {
            Button("Saqué dobles") {
                model.leaveJail(.doubles)
            }
            Button("Pagar $\(GameRules.jailFine)") {
                model.leaveJail(.payFine)
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(model.isFreeParkingEnabled
                 ? "La fianza de $\(GameRules.jailFine) va al bote de Free Parking."
                 : "La fianza de $\(GameRules.jailFine) se paga a la banca.")
        }
    }
}
