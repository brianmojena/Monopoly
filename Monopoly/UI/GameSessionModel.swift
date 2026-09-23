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
    /// Happiness changes of the player this device is playing as, shown one by one.
    @Published private(set) var happinessToasts: [HappinessToast] = []
    /// A Life Card this device's player just drew, to show it full size.
    @Published var presentedLifeCard: LifeCardDraw?
    /// A Life Card another player just drew (the card is public, its effect is not).
    @Published private(set) var lifeCardNotice: LifeCardDraw?
    /// A board event that just happened, announced on every device.
    @Published var presentedBoardEvent: BoardEventOccurrence?

    let proximity = ProximityPaymentCoordinator()

    private let session: GameSession

    var isProximityPaymentEnabled: Bool {
        gameState?.proximityPaymentsEnabled == true
    }

    var areCreditCardsEnabled: Bool {
        gameState?.activeHouseRules.contains(.creditCards) == true
    }

    var isFreeParkingEnabled: Bool {
        gameState?.activeHouseRules.contains(.freeParkingJackpot) == true
    }

    /// Whether the player this device is playing as may see the property's level
    /// (and so its rent). With secret levels, only its shareholders can.
    func canSeeLevel(of property: Property) -> Bool {
        guard gameState?.activeHouseRules.contains(.hiddenPropertyLevels) == true, property.isOwned else {
            return true
        }
        guard let localPlayerID else {
            return false
        }
        return property.shares(of: localPlayerID) > 0
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

    var isMonopolife: Bool {
        gameState?.monopolife != nil
    }

    /// The Monopolife profile of the player this device is playing as.
    var localProfile: LifeProfile? {
        guard let localPlayerID else {
            return nil
        }
        return gameState?.monopolife?.profiles[localPlayerID]
    }

    /// Players on this device who still have to see their role, the device owner
    /// first; on the host, followed by the players without a phone.
    var pendingRoleReveals: [Player] {
        guard let monopolife = gameState?.monopolife, !monopolife.isFinished else {
            return []
        }
        let unacknowledged = controllablePlayers.filter {
            monopolife.profiles[$0.id]?.hasAcknowledgedRole == false
        }
        return unacknowledged.filter { $0.id == ownPlayerID } + unacknowledged.filter { $0.id != ownPlayerID }
    }

    var localPendingLifeCard: LifeCardDraw? {
        guard let pending = gameState?.monopolife?.pendingLifeCard, pending.playerID == localPlayerID else {
            return nil
        }
        return pending
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

    /// The room this device hosts or joined; nil while a client is still browsing.
    var roomID: UUID? {
        role == .host ? session.roomID : joinedRoomID
    }

    private var hostControlledPlayerIDs: Set<UUID>
    private let store: GameStore?
    private let joinedGamesStore: JoinedGamesStore?
    private var joinName: String?
    /// The host's name as the room advertised it, kept for "Partidas recientes".
    private(set) var joinedRoomName = ""

    /// - Parameters:
    ///   - hostControlledPlayerIDs: when resuming a saved game, the players that
    ///     act from the host's iPhone.
    ///   - store: where the host saves every state change; nil disables saving.
    ///   - joinedGamesStore: where a client remembers the games it joins; nil
    ///     disables it.
    ///   - joinName: the name a client typed, used to find its player again when it
    ///     rejoins a game that already started.
    init(
        session: GameSession,
        role: Role,
        localPlayerID: UUID? = nil,
        hostControlledPlayerIDs: Set<UUID> = [],
        store: GameStore? = nil,
        joinedGamesStore: JoinedGamesStore? = nil,
        joinName: String? = nil
    ) {
        self.session = session
        self.role = role
        self.ownPlayerID = localPlayerID
        self.hostControlledPlayerIDs = hostControlledPlayerIDs
        self.store = store
        self.joinedGamesStore = joinedGamesStore
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
                guard let self, self.gameState == nil else {
                    return
                }
                self.lobby = lobby
                self.rememberJoinedGame()
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

    // MARK: Creating a game

    private static func makeTransport() -> MultipeerGameTransport {
        MultipeerGameTransport(displayName: "Monopoly-\(UUID().uuidString.prefix(8))")
    }

    /// A new room in its waiting room, with the host named after the app's setting.
    static func hosting(playerName: String) -> GameSessionModel {
        let hostPlayer = LobbyPlayer(name: playerName, isHostControlled: true)
        let session = GameSession(
            transport: makeTransport(),
            role: .host,
            lobby: Lobby(players: [hostPlayer]),
            hostPlayerID: hostPlayer.id
        )
        return GameSessionModel(session: session, role: .host, localPlayerID: hostPlayer.id, store: .shared)
    }

    /// A game this iPhone hosted before, advertised again under the same room so
    /// its players rejoin it on their own.
    static func resuming(_ savedGame: SavedGame) -> GameSessionModel {
        let session = GameSession(
            transport: makeTransport(),
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
            store: .shared
        )
        if let currentPlayerID = savedGame.state.currentPlayerID,
           savedGame.hostControlledPlayerIDs.contains(currentPlayerID) {
            model.selectPlayer(currentPlayerID)
        }
        return model
    }

    /// A client looking for nearby rooms.
    static func browsing() -> GameSessionModel {
        GameSessionModel(session: GameSession(transport: makeTransport(), role: .client), role: .client, joinedGamesStore: .shared)
    }

    /// A client going back to a game it joined before, as the same player. It
    /// connects as soon as the host's room shows up nearby.
    static func rejoining(_ joinedGame: JoinedGame, playerName: String) -> GameSessionModel {
        let model = browsing()
        model.joinedRoomName = joinedGame.hostName
        model.join(
            roomID: joinedGame.roomID,
            as: LobbyPlayer(id: joinedGame.playerID, name: playerName, isHostControlled: false)
        )
        model.isHostConnected = false
        return model
    }

    func selectPlayer(_ playerID: UUID) {
        localPlayerID = playerID
        rememberJoinedGame()
    }

    func join(_ room: DiscoveredRoom, name: String) {
        joinedRoomName = room.name
        join(roomID: room.id, as: LobbyPlayer(name: name, isHostControlled: false))
    }

    private func join(roomID: UUID, as player: LobbyPlayer) {
        localPlayerID = player.id
        joinName = player.name
        joinedRoomID = roomID
        isHostConnected = true
        session.join(roomID: roomID, as: player)
        rememberJoinedGame()
    }

    /// Leaves the game for good on this iPhone: stops advertising or browsing and
    /// drops every connection. A host's game stays saved.
    func close() {
        proximity.stopPayment()
        session.close()
    }

    /// See `GameSession.resumeNetworking()`.
    func resumeNetworking() {
        session.resumeNetworking()
    }

    // Keeps the joined game in "Partidas recientes" up to date, so the player can
    // go back to it as the same player after closing the app.
    private func rememberJoinedGame() {
        guard role == .client, let joinedGamesStore, let joinedRoomID, let localPlayerID else {
            return
        }
        joinedGamesStore.save(JoinedGame(
            roomID: joinedRoomID,
            hostName: joinedRoomName,
            playerID: localPlayerID,
            playerNames: gameState?.players.map(\.name) ?? lobby?.players.map(\.name) ?? [],
            round: gameState?.round,
            mode: gameState?.mode ?? lobby?.gameMode ?? .classic,
            lastPlayedAt: Date()
        ))
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
        let previousState = gameState
        gameState = state
        announceMonopolifeChanges(from: previousState, to: state)
        if previousState != nil,
           let occurrence = state.boardEvents?.lastOccurrence,
           occurrence.sequence != previousState?.boardEvents?.lastOccurrence?.sequence {
            presentedBoardEvent = occurrence
        }
        lobby = nil
        save(state)
        reclaimPlayerByName(in: state)
        rememberJoinedGame()

        // A player without a phone acts from the host's iPhone, so the host follows
        // the turn to them automatically.
        if role == .host,
           let currentPlayerID = state.currentPlayerID,
           currentPlayerID != previousPlayerID,
           hostControlledPlayerIDs.contains(currentPlayerID) {
            localPlayerID = currentPlayerID
        }
    }

    private func announceMonopolifeChanges(from previousState: GameState?, to state: GameState) {
        guard let monopolife = state.monopolife, let previous = previousState?.monopolife else {
            return
        }

        if monopolife.happinessLog.count > previous.happinessLog.count {
            let newEvents = monopolife.happinessLog
                .suffix(from: previous.happinessLog.count)
                .filter { $0.playerID == localPlayerID }
            happinessToasts.append(contentsOf: newEvents.map { HappinessToast(event: $0) })
        }

        if let draw = monopolife.lastLifeCardDraw, draw.sequence != previous.lastLifeCardDraw?.sequence {
            if draw.playerID == localPlayerID {
                presentedLifeCard = draw
            } else {
                lifeCardNotice = draw
            }
        }
    }

    func dismissHappinessToast(_ toast: HappinessToast) {
        happinessToasts.removeAll { $0.id == toast.id }
    }

    func dismissLifeCardNotice() {
        lifeCardNotice = nil
    }

    func acknowledgeRole(for playerID: UUID) {
        send(.acknowledgeRole(playerID: playerID), as: playerID)
    }

    func drawLifeCard() {
        guard let localPlayerID else {
            alertMessage = "Selecciona tu jugador antes de sacar una tarjeta."
            return
        }

        send(.drawLifeCard(playerID: localPlayerID))
    }

    func resolveLifeCard(accept: Bool) {
        guard let localPlayerID else {
            alertMessage = "Selecciona tu jugador antes de decidir."
            return
        }

        send(.resolveLifeCardDecision(playerID: localPlayerID, accept: accept))
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
        case .gameFinished:
            return "La partida ya terminó."
        case .monopolifeOnly:
            return "Eso solo existe en Monopolife."
        case .lifeCardDecisionPending:
            return "Primero decide qué hacer con tu Tarjeta de Vida."
        case .noPendingLifeCard:
            return "No tienes ninguna Tarjeta de Vida pendiente."
        case .creditCut:
            return "La banca ya no te da crédito: fallaste \(GameRules.missedPaymentsBeforeCreditIsCut) pagos."
        case let .creditCardLoanLimitReached(maximum):
            return maximum == 1
                ? "Solo puedes tener un préstamo a la vez hasta que termines de pagar uno."
                : "Ya tienes \(maximum) préstamos, el máximo a la vez."
        case .freeParkingDisabled:
            return "El bote de Free Parking no está activado en esta partida."
        case .freeParkingPotEmpty:
            return "El bote de Free Parking está vacío."
        case let .insufficientFunds(_, required, available):
            return "No te alcanza: hacen falta $\(required) y tienes $\(available)."
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

    func payTravel(route: TravelRoute) {
        guard let localPlayerID else {
            alertMessage = "Selecciona tu jugador antes de pagar un viaje."
            return
        }

        send(.payTravel(playerID: localPlayerID, route: route))
    }

    func collectFreeParking() {
        guard let localPlayerID else {
            alertMessage = "Selecciona tu jugador antes de cobrar el bote."
            return
        }

        send(.collectFreeParking(playerID: localPlayerID))
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

        send(intent, as: localPlayerID)
    }

    private func send(_ intent: GameIntent, as playerID: UUID) {
        do {
            switch role {
            case .host:
                try session.submitLocal(intent: intent, playerID: playerID)
            case .client:
                try session.submit(intent: intent, playerID: playerID)
            }
        } catch {
            alertMessage = Self.isDisconnection(error)
                ? "Sin conexión con la banca (el iPhone del host). Se reconecta sola en cuanto esté cerca y con la app abierta; vuelve a intentarlo entonces."
                : "No se pudo enviar la acción: \(error.localizedDescription)"
        }
    }

    private static func isDisconnection(_ error: Error) -> Bool {
        switch error {
        case GameSessionError.hostNotConnected, GameTransportError.peerNotConnected:
            return true
        default:
            return false
        }
    }

    private func sendProximitySignal(_ signal: ProximitySignal) {
        do {
            try session.sendProximitySignal(signal)
        } catch {
            alertMessage = Self.isDisconnection(error)
                ? "Sin conexión con la banca: no se puede avisar al otro iPhone hasta que vuelva la conexión."
                : "No se pudo contactar al otro iPhone: \(error.localizedDescription)"
        }
    }

    func dismissAlert() {
        alertMessage = nil
    }
}

struct HappinessToast: Identifiable, Equatable {
    let id = UUID()
    let event: HappinessEvent
}
