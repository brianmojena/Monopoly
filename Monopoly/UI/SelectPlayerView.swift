import SwiftUI

struct SelectPlayerView: View {
    @ObservedObject var model: GameSessionModel
    @State private var selectedPlayerID: UUID?

    var body: some View {
        if let state = model.gameState {
            VStack(alignment: .leading, spacing: 20) {
                Text("El host ya creó la partida. Selecciona tu nombre para enviar tus acciones.")
                    .foregroundStyle(.secondary)

                Picker("Tu jugador", selection: $selectedPlayerID) {
                    ForEach(state.players) { player in
                        Text(player.name).tag(Optional(player.id))
                    }
                }
                .pickerStyle(.menu)

                Button("Continuar") {
                    if let selectedPlayerID {
                        model.selectPlayer(selectedPlayerID)
                    }
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .disabled(selectedPlayerID == nil)

                Spacer()
            }
            .padding(24)
            .onAppear {
                if selectedPlayerID == nil {
                    selectedPlayerID = state.players.first?.id
                }
            }
        } else {
            ProgressView("Esperando estado de la partida…")
        }
    }
}
