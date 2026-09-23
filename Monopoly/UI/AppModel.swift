import Combine
import Foundation
#if os(iOS)
import UIKit
#endif

/// Owns the game this iPhone is in. The game lives here rather than in a pushed
/// screen, so going back or swiping can't drop it: it only ends through "Salir de
/// la partida". It is also remembered, so reopening the app goes straight back to it.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var activeGame: GameSessionModel?

    private let gameStore: GameStore
    private let joinedGamesStore: JoinedGamesStore

    init() {
        gameStore = .shared
        joinedGamesStore = .shared
        restoreActiveGame()
    }

    func hostNewGame() {
        activate(.hosting(playerName: AppSettings.playerName))
    }

    func resume(_ savedGame: SavedGame) {
        activate(.resuming(savedGame))
    }

    func rejoin(_ joinedGame: JoinedGame) {
        activate(.rejoining(joinedGame, playerName: AppSettings.playerName))
    }

    /// A client that just joined a room from the room list.
    func didJoin(_ model: GameSessionModel) {
        activate(model)
    }

    /// Ends the game on this iPhone. A host's game stays saved for "Partidas
    /// recientes" unless `deletingSave` is set.
    func leaveActiveGame(deletingSave: Bool = false) {
        guard let activeGame else {
            return
        }
        activeGame.close()
        if deletingSave, activeGame.role == .host, let roomID = activeGame.roomID {
            gameStore.delete(roomID: roomID)
        }
        ActiveGameRecord.save(nil)
        self.activeGame = nil
        updateIdleTimer()
    }

    func deleteSavedGame(roomID: UUID) {
        gameStore.delete(roomID: roomID)
    }

    func forgetJoinedGame(roomID: UUID) {
        joinedGamesStore.delete(roomID: roomID)
    }

    /// The app came back to the foreground.
    func sceneDidBecomeActive() {
        activeGame?.resumeNetworking()
        updateIdleTimer()
    }

    private func activate(_ model: GameSessionModel) {
        activeGame?.close()
        activeGame = model
        // A host still in its waiting room has no save yet; if the app closes then,
        // `restoreActiveGame` finds nothing to reopen and forgets the record.
        if let roomID = model.roomID {
            ActiveGameRecord.save(ActiveGameRecord(roomID: roomID, role: model.role == .host ? .host : .client))
        }
        updateIdleTimer()
    }

    private func restoreActiveGame() {
        guard let record = ActiveGameRecord.load() else {
            return
        }
        switch record.role {
        case .host:
            if let savedGame = gameStore.load(roomID: record.roomID) {
                resume(savedGame)
                return
            }
        case .client:
            if let joinedGame = joinedGamesStore.load(roomID: record.roomID) {
                rejoin(joinedGame)
                return
            }
        }
        ActiveGameRecord.save(nil)
    }

    private func updateIdleTimer() {
#if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = activeGame != nil && AppSettings.keepsScreenOn
#endif
    }
}
