import Combine
import Foundation

@MainActor
final class GameSessionModel: ObservableObject {
    enum Role {
        case host
        case client
    }

    static let placeholderInitialBalance = 1500

    let role: Role

    @Published private(set) var gameState: GameState?
    @Published private(set) var alertMessage: String?
    @Published private(set) var localPlayerID: UUID?

    private let session: GameSession

    init(session: GameSession, role: Role, localPlayerID: UUID? = nil) {
        self.session = session
        self.role = role
        self.gameState = session.gameState
        self.localPlayerID = localPlayerID

        session.onStateChanged = { [weak self] state in
            DispatchQueue.main.async {
                self?.gameState = state
            }
        }
        session.onIntentRejected = { [weak self] error in
            DispatchQueue.main.async {
                self?.alertMessage = "La acción fue rechazada: \(String(describing: error))"
            }
        }
        session.onTransportError = { [weak self] error in
            DispatchQueue.main.async {
                self?.alertMessage = "Error de conexión: \(error.localizedDescription)"
            }
        }
    }

    func selectPlayer(_ playerID: UUID) {
        localPlayerID = playerID
    }

    func buy(propertyID: UUID) {
        guard let localPlayerID else {
            alertMessage = "Selecciona tu jugador antes de comprar."
            return
        }

        let intent = GameIntent.buyProperty(playerID: localPlayerID, propertyID: propertyID)

        do {
            switch role {
            case .host:
                try session.submitLocal(intent: intent, playerID: localPlayerID)
            case .client:
                try session.submit(intent: intent, playerID: localPlayerID)
            }
        } catch {
            alertMessage = "No se pudo enviar la acción: \(error.localizedDescription)"
        }
    }

    func dismissAlert() {
        alertMessage = nil
    }
}
