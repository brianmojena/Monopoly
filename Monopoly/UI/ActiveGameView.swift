import SwiftUI

/// The game this iPhone is in, shown instead of the start screen. It has its own
/// navigation stack with no way back: the only way out is "Salir", which asks first.
struct ActiveGameView: View {
    @ObservedObject var model: GameSessionModel
    @EnvironmentObject private var appModel: AppModel
    @State private var isConfirmingExit = false

    var body: some View {
        NavigationStack {
            Group {
                switch model.role {
                case .host:
                    HostGameView(model: model)
                case .client:
                    JoinedGameView(model: model)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        isConfirmingExit = true
                    } label: {
                        Label("Salir", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .confirmationDialog(exitTitle, isPresented: $isConfirmingExit, titleVisibility: .visible) {
                exitActions
            } message: {
                Text(exitMessage)
            }
        }
    }

    private var isHostInGame: Bool {
        model.role == .host && model.gameState != nil
    }

    private var exitTitle: String {
        if model.role == .host, model.gameState == nil {
            return "¿Cerrar la sala?"
        }
        return "¿Salir de la partida?"
    }

    private var exitMessage: String {
        switch model.role {
        case .host where model.gameState == nil:
            return "Los jugadores que ya entraron saldrán de la sala."
        case .host:
            return "La partida queda guardada en Partidas recientes para continuarla. Mientras tanto, los demás no pueden jugar: tu iPhone es la banca."
        case .client:
            return "Podrás volver como el mismo jugador desde Partidas recientes, en Inicio."
        }
    }

    @ViewBuilder
    private var exitActions: some View {
        if isHostInGame {
            Button("Salir y guardar") {
                appModel.leaveActiveGame()
            }
            Button("Terminar y borrar la partida", role: .destructive) {
                appModel.leaveActiveGame(deletingSave: true)
            }
        } else if model.role == .host {
            Button("Cerrar sala", role: .destructive) {
                appModel.leaveActiveGame()
            }
        } else {
            Button("Salir de la partida", role: .destructive) {
                appModel.leaveActiveGame()
            }
        }
    }
}
