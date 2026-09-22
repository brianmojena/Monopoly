import SwiftUI

struct JoinView: View {
    @StateObject private var model: GameSessionModel

    init() {
        let transport = MultipeerGameTransport(displayName: "Monopoly-\(UUID().uuidString.prefix(8))")
        let session = GameSession(transport: transport, role: .client)
        _model = StateObject(wrappedValue: GameSessionModel(session: session, role: .client))
    }

    var body: some View {
        Group {
            if model.gameState == nil {
                searchingView
            } else if model.localPlayerID == nil {
                SelectPlayerView(model: model)
            } else {
                GameBoardView(model: model)
            }
        }
        .navigationTitle(model.gameState == nil ? "Unirse a partida" : "Selecciona tu jugador")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }

    private var searchingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Buscando partida…")
                .font(.headline)
            Text("Asegúrate de que el host ya inició la partida y que ambos dispositivos están en la misma red local.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(24)
    }
}

#Preview {
    NavigationStack {
        JoinView()
    }
}
