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
    @Published private(set) var isHostConnected = true
    @Published private(set) var rooms: [DiscoveredRoom] = []
    @Published private(set) var joinedRoomID: UUID?

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

    private var hostControlledPlayerIDs: Set<UUID>
    private let store: GameStore?
    private var joinName: String?

    /// - Parameters:
    ///   - hostControlledPlayerIDs: when resuming a saved game, the players that
    ///     act from the host's iPhone.
    ///   - store: where the host saves every state change; nil disables saving.
    ///   - joinName: the name a client typed, used to find its player again when it
    ///     rejoins a game that already started.
    init(
        session: GameSession,
        role: Role,
        localPlayerID: UUID? = nil,
        hostControlledPlayerIDs: Set<UUID> = [],
        store: GameStore? = nil,
        joinName: String? = nil
    ) {
        self.session = session
        self.role = role
        self.ownPlayerID = localPlayerID
        self.hostControlledPlayerIDs = hostControlledPlayerIDs
        self.store = store
        self.joinName = joinName
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
        session.onRoomsChanged = { [weak self] rooms in
            DispatchQueue.main.async {
                self?.rooms = rooms
            }
        }
        session.onHostConnectionChanged = { [weak self] isConnected in
            DispatchQueue.main.async {
                self?.isHostConnected = isConnected
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

    func join(_ room: DiscoveredRoom, name: String) {
        let player = LobbyPlayer(name: name, isHostControlled: false)
        localPlayerID = player.id
        joinName = name
        joinedRoomID = room.id
        isHostConnected = true
        session.join(roomID: room.id, as: player)
    }

    func leaveRoom() {
        session.leaveRoom()
        joinedRoomID = nil
        localPlayerID = nil
        joinName = nil
        gameState = nil
        lobby = nil
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
        save(state)
        reclaimPlayerByName(in: state)

        // A player without a phone acts from the host's iPhone, so the host follows
        // the turn to them automatically.
        if role == .host,
           let currentPlayerID = state.currentPlayerID,
           currentPlayerID != previousPlayerID,
           hostControlledPlayerIDs.contains(currentPlayerID) {
            localPlayerID = currentPlayerID
        }
    }

    private func save(_ state: GameState) {
        guard role == .host, let store, let ownPlayerID else {
            return
        }

        do {
            try store.save(SavedGame(
                roomID: session.roomID,
                state: state,
                ownPlayerID: ownPlayerID,
                hostControlledPlayerIDs: hostControlledPlayerIDs,
                savedAt: Date()
            ))
        } catch {
            alertMessage = "No se pudo guardar la partida: \(error.localizedDescription)"
        }
    }

    // A player who closed the app and joins again gets a new ID; matching the name
    // they typed puts them back on their player instead of asking them to pick it.
    private func reclaimPlayerByName(in state: GameState) {
        guard role == .client,
              let joinName,
              !state.players.contains(where: { $0.id == localPlayerID }) else {
            return
        }

        let matches = state.players.filter {
            $0.name.compare(joinName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        if matches.count == 1 {
            localPlayerID = matches[0].id
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

    func levelUp(propertyID: UUID) {
        guard let localPlayerID else {
            alertMessage = "Selecciona tu jugador antes de construir."
            return
        }

        send(.levelUp(propertyID: propertyID, playerID: localPlayerID))
    }

    func levelDown(propertyID: UUID) {
        guard let localPlayerID else {
            alertMessage = "Selecciona tu jugador antes de vender construcciones."
            return
        }

        send(.levelDown(propertyID: propertyID, playerID: localPlayerID))
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

    func proposeDeal(_ deal: MarketDeal) {
        guard let localPlayerID else {
            alertMessage = "Selecciona tu jugador antes de proponer un trato."
            return
        }

        send(.proposeDeal(MarketDeal(
            id: deal.id,
            proposerID: localPlayerID,
            transfers: deal.transfers,
            sharedPurchase: deal.sharedPurchase,
            proposedInvestment: deal.proposedInvestment,
            cancelInvestment: deal.cancelInvestment
        )))
    }

    func acceptDeal(_ dealID: UUID) {
        send(.acceptDeal(dealID: dealID))
    }

    func rejectDeal(_ dealID: UUID) {
        send(.rejectDeal(dealID: dealID))
    }

    /// Deals this device's player still has to answer (not counting open offers).
    var dealsAwaitingLocalPlayer: [MarketDeal] {
        guard let localPlayerID, let gameState else {
            return []
        }
        return gameState.marketDeals.filter {
            !$0.isOpenOffer && $0.pendingPlayerIDs.contains(localPlayerID)
        }
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
