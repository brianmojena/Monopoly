import SwiftUI

struct ResumeHostView: View {
    @StateObject private var model: GameSessionModel

    // Built inside the StateObject autoclosure so the host only starts advertising
    // when this screen is actually shown, not when the start screen renders.
    init(savedGame: SavedGame) {
        _model = StateObject(wrappedValue: Self.makeModel(savedGame: savedGame))
    }

    var body: some View {
        GameBoardView(model: model)
    }

    private static func makeModel(savedGame: SavedGame) -> GameSessionModel {
        let transport = MultipeerGameTransport(displayName: "Monopoly-\(UUID().uuidString.prefix(8))")
        let session = GameSession(
            transport: transport,
            role: .host,
            initialState: savedGame.state,
            roomID: savedGame.roomID,
            hostPlayerID: savedGame.ownPlayerID
        )
        let model = GameSessionModel(
            session: session,
            role: .host,
            localPlayerID: savedGame.ownPlayerID,
            hostControlledPlayerIDs: savedGame.hostControlledPlayerIDs,
            store: GameStore.shared
        )
        if let currentPlayerID = savedGame.state.currentPlayerID,
           savedGame.hostControlledPlayerIDs.contains(currentPlayerID) {
            model.selectPlayer(currentPlayerID)
        }
        return model
    }
}
