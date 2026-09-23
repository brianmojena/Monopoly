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
    let ownPlayerID: UUID?

    @Published private(set) var gameState: GameState?
    @Published private(set) var alertMessage: String?
    @Published private(set) var localPlayerID: UUID?
    @Published private(set) var lobby: Lobby?

    let proximity = ProximityPaymentCoordinator()

    private let session: GameSession

    var isProximityPaymentEnabled: Bool {
        gameState?.proximityPaymentsEnabled == true
    }

    var areCreditCardsEnabled: Bool {
        gameState?.activeHouseRules.contains(.creditCards) == true
    }

    /// Players this device acts for: on the host, its own player plus the players
    /// added without a phone; on a client, just its own player.
    var controllablePlayers: [Player] {
        guard let gameState else {
            return []
        }
        switch role {
        case .host:
            return gameState.players.filter { hostControlledPlayerIDs.contains($0.id) }
        case .client:
            return gameState.players.filter { $0.id == localPlayerID }
        }
    }

    var currentPlayer: Player? {
        gameState?.players.first(where: { $0.id == gameState?.currentPlayerID })
    }

    var isLocalPlayersTurn: Bool {
        guard let gameState else {
            return false
        }
        return gameState.currentPlayerID == nil || gameState.currentPlayerID == localPlayerID
    }

    private var hostControlledPlayerIDs: Set<UUID> = []

    init(session: GameSession, role: Role, localPlayerID: UUID? = nil) {
        self.session = session
        self.role = role
        self.ownPlayerID = localPlayerID
        self.gameState = session.gameState
        self.lobby = session.lobby
        self.localPlayerID = localPlayerID

        session.onStateChanged = { [weak self] state in
            DispatchQueue.main.async {
                self?.receive(state)
            }
        }
        session.onLobbyChanged = { [weak self] lobby in
            DispatchQueue.main.async {
                guard self?.gameState == nil else {
                    return
                }
                self?.lobby = lobby
            }
        }
        session.onIntentRejected = { [weak self] error in
            DispatchQueue.main.async {
                self?.alertMessage = self?.message(for: error)
            }
        }
        session.onTransportError = { [weak self] error in
            DispatchQueue.main.async {
                self?.alertMessage = "Error de conexión: \(error.localizedDescription)"
            }
        }
        session.onProximitySignal = { [weak self] signal in
            DispatchQueue.main.async {
                guard let self, self.isProximityPaymentEnabled else {
                    return
                }
                self.proximity.handle(signal, localPlayerID: self.localPlayerID)
            }
        }
        proximity.sendSignal = { [weak self] signal in
            self?.sendProximitySignal(signal)
        }
    }

    func selectPlayer(_ playerID: UUID) {
        localPlayerID = playerID
    }

    func updateLobby(_ change: (inout Lobby) -> Void) {
        guard var updatedLobby = lobby else {
            return
        }
        change(&updatedLobby)
        lobby = updatedLobby

        do {
            try session.updateLobby(updatedLobby)
        } catch {
            alertMessage = "No se pudo actualizar la sala: \(error.localizedDescription)"
        }
    }

    func startGame() {
        guard let lobby, lobby.canStart else {
            return
        }

        hostControlledPlayerIDs = Set(lobby.players.filter(\.isHostControlled).map(\.id))
        let state = lobby.makeGameState(
            initialBalance: Self.placeholderInitialBalance,
            properties: PlaceholderProperties.all
        )
        do {
            try session.startGame(with: state)
            self.lobby = nil
        } catch {
            alertMessage = "No se pudo iniciar la partida: \(error.localizedDescription)"
        }
    }

    func endTurn() {
        guard let localPlayerID else {
            alertMessage = "Selecciona tu jugador antes de terminar el turno."
            return
        }

        send(.endTurn(playerID: localPlayerID))
    }

    func skipTurn() {
        send(.skipTurn)
    }

    private func receive(_ state: GameState) {
        let previousPlayerID = gameState?.currentPlayerID
        gameState = state
        lobby = nil

        // A player without a phone acts from the host's iPhone, so the host follows
        // the turn to them automatically.
        if role == .host,
           let currentPlayerID = state.currentPlayerID,
           currentPlayerID != previousPlayerID,
           hostControlledPlayerIDs.contains(currentPlayerID) {
            localPlayerID = currentPlayerID
        }
    }

    private func message(for error: GameRuleError) -> String {
        switch error {
        case let .notPlayersTurn(currentPlayerID):
            let name = gameState?.players.first(where: { $0.id == currentPlayerID })?.name ?? "otro jugador"
            return "No es tu turno. Ahora juega \(name)."
        case .onlyHostCanSkipTurn:
            return "Solo el host puede pasar el turno de otro jugador."
        default:
            return "La acción fue rechazada: \(String(describing: error))"
        }
    }

    func buy(propertyID: UUID) {
        guard let localPlayerID else {
            alertMessage = "Selecciona tu jugador antes de comprar."
            return
        }

        send(.buyProperty(playerID: localPlayerID, propertyID: propertyID))
    }

    func payRent(propertyID: UUID) {
        guard let localPlayerID else {
            alertMessage = "Selecciona tu jugador antes de pagar renta."
            return
        }

        send(.collectRent(payerID: localPlayerID, propertyID: propertyID))
    }

    func mortgage(propertyID: UUID) {
        guard let localPlayerID else {
            alertMessage = "Selecciona tu jugador antes de hipotecar."
            return
        }

        send(.mortgageProperty(propertyID: propertyID, playerID: localPlayerID))
    }

    func unmortgage(propertyID: UUID) {
        guard let localPlayerID else {
            alertMessage = "Selecciona tu jugador antes de deshipotecar."
            return
        }

        send(.unmortgageProperty(propertyID: propertyID, playerID: localPlayerID))
    }

    func buildHouse(propertyID: UUID) {
        guard let localPlayerID else {
            alertMessage = "Selecciona tu jugador antes de construir."
            return
        }

        send(.buildHouse(propertyID: propertyID, playerID: localPlayerID))
    }

    func buildHotel(propertyID: UUID) {
        guard let localPlayerID else {
            alertMessage = "Selecciona tu jugador antes de construir."
            return
        }

        send(.buildHotel(propertyID: propertyID, playerID: localPlayerID))
    }

    func sellHouse(propertyID: UUID) {
        guard let localPlayerID else {
            alertMessage = "Selecciona tu jugador antes de vender construcciones."
            return
        }

        send(.sellHouse(propertyID: propertyID, playerID: localPlayerID))
    }

    func payTax(amount: Int) {
        guard let localPlayerID else {
            alertMessage = "Selecciona tu jugador antes de pagar impuestos."
            return
        }

        send(.payTax(playerID: localPlayerID, amount: amount))
    }

    func collectSalary(amount: Int, postponedLoanIDs: Set<UUID> = []) {
        guard let localPlayerID else {
            alertMessage = "Selecciona tu jugador antes de cobrar salario."
            return
        }

        send(.collectSalary(playerID: localPlayerID, amount: amount, postponedLoanIDs: postponedLoanIDs))
    }

    func transfer(to recipientID: UUID, amount: Int) {
        guard let localPlayerID else {
            alertMessage = "Selecciona tu jugador antes de pagar a otro jugador."
            return
        }

        send(.transferMoney(payerID: localPlayerID, recipientID: recipientID, amount: amount))
    }

    func borrowOnCreditCard(amount: Int, installments: Int) {
        guard let localPlayerID else {
            alertMessage = "Selecciona tu jugador antes de pedir un préstamo."
            return
        }

        send(.borrowOnCreditCard(playerID: localPlayerID, amount: amount, installments: installments))
    }

    func payCreditCard(loanID: UUID, amount: Int) {
        guard let localPlayerID else {
            alertMessage = "Selecciona tu jugador antes de pagar la tarjeta."
            return
        }

        send(.payCreditCard(playerID: localPlayerID, loanID: loanID, amount: amount))
    }

    func executeTrade(offer: TradeOffer) {
        guard let localPlayerID else {
            alertMessage = "Selecciona tu jugador antes de proponer un intercambio."
            return
        }

        let localOffer = TradeOffer(
            fromPlayerID: localPlayerID,
            toPlayerID: offer.toPlayerID,
            offeredPropertyIDs: offer.offeredPropertyIDs,
            offeredMoney: offer.offeredMoney,
            requestedPropertyIDs: offer.requestedPropertyIDs,
            requestedMoney: offer.requestedMoney
        )
        send(.executeTrade(offer: localOffer))
    }

    func resolveAuction(propertyID: UUID, bids: [AuctionBid]) {
        guard localPlayerID != nil else {
            alertMessage = "Selecciona tu jugador antes de cerrar la subasta."
            return
        }

        send(.resolveAuction(propertyID: propertyID, bids: bids))
    }

    func declareBankruptcy(creditor: DebtCreditor) {
        guard let localPlayerID else {
            alertMessage = "Selecciona tu jugador antes de declarar bancarrota."
            return
        }

        send(.declareBankruptcy(playerID: localPlayerID, creditor: creditor))
    }

    private func send(_ intent: GameIntent) {
        guard let localPlayerID else {
            alertMessage = "Selecciona tu jugador antes de realizar una acción."
            return
        }

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

    private func sendProximitySignal(_ signal: ProximitySignal) {
        do {
            try session.sendProximitySignal(signal)
        } catch {
            alertMessage = "No se pudo contactar al otro iPhone: \(error.localizedDescription)"
        }
    }

    func dismissAlert() {
        alertMessage = nil
    }
}
