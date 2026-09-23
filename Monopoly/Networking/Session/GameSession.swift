import Foundation

enum GameSessionError: Error, Equatable {
    case hostCannotSubmitIntent
    case hostNotConnected
    case hostRequiresInitialState
    case onlyHostCanManageLobby
    case gameAlreadyStarted
}

final class GameSession {
    enum Role {
        case host
        case client
    }

    private let transport: GameTransport
    private let role: Role
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let configuredHostPeerID: PeerID?
    // MultipeerConnectivity invokes MCSessionDelegate callbacks on its own
    // private background queue, potentially from multiple peers concurrently.
    // All mutable session state is confined to this serial queue so those
    // callbacks (and any local submit/send call) never race with each other.
    private let stateQueue = DispatchQueue(label: "com.monopoly.gamesession.state")
    private var connectedPeerIDs: Set<PeerID> = []
    private var discoveredHostPeerID: PeerID?
    private var _gameState: GameState?
    private var _lobby: Lobby?
    private var lobbyPlayerIDsByPeer: [PeerID: Set<UUID>] = [:]
    private var lobbyPlayer: LobbyPlayer?
    let roomID: UUID
    private let hostPlayerID: UUID?
    private var discoveredRooms: [PeerID: DiscoveredRoom] = [:]
    private var joinedRoomID: UUID?
    private var _lastIntentRejection: GameRuleError?

    var gameState: GameState? {
        stateQueue.sync { return _gameState }
    }

    var lastIntentRejection: GameRuleError? {
        stateQueue.sync { return _lastIntentRejection }
    }

    var currentState: GameState? {
        gameState
    }

    var lobby: Lobby? {
        stateQueue.sync { return _lobby }
    }

    var rooms: [DiscoveredRoom] {
        stateQueue.sync { sortedRooms() }
    }

    var onStateChanged: ((GameState) -> Void)?
    var onIntentRejected: ((GameRuleError) -> Void)?
    var onTransportError: ((Error) -> Void)?
    var onProximitySignal: ((ProximitySignal) -> Void)?
    var onLobbyChanged: ((Lobby) -> Void)?
    var onHostConnectionChanged: ((Bool) -> Void)?
    var onRoomsChanged: (([DiscoveredRoom]) -> Void)?

    /// A host starts either with a running game (`initialState`) or with a `lobby`
    /// that players join before `startGame`, and advertises it as room `roomID`,
    /// named after `hostPlayerID`. A client browses rooms and joins one with
    /// `join(roomID:as:)`; passing `lobbyPlayer` joins the lobby of whichever host it
    /// is connected to (used by tests that connect transports directly).
    init(
        transport: GameTransport,
        role: Role,
        initialState: GameState? = nil,
        lobby: Lobby? = nil,
        lobbyPlayer: LobbyPlayer? = nil,
        roomID: UUID = UUID(),
        hostPlayerID: UUID? = nil,
        hostPeerID: PeerID? = nil,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        if case .host = role, initialState == nil, lobby == nil {
            preconditionFailure(GameSessionError.hostRequiresInitialState.localizedDescription)
        }

        self.transport = transport
        self.role = role
        self.encoder = encoder
        self.decoder = decoder
        self.configuredHostPeerID = hostPeerID
        self._gameState = initialState
        self._lobby = initialState == nil ? lobby : nil
        self.lobbyPlayer = lobbyPlayer
        self.roomID = roomID
        self.hostPlayerID = hostPlayerID
        self.discoveredHostPeerID = hostPeerID

        transport.onDataReceived = { [weak self] data, peerID in
            self?.receive(data: data, from: peerID)
        }
        transport.onPeerConnected = { [weak self] peerID in
            self?.peerConnected(peerID)
        }
        transport.onPeerDisconnected = { [weak self] peerID in
            self?.peerDisconnected(peerID)
        }
        transport.onPeerFound = { [weak self] peerID, info in
            self?.peerFound(peerID, info: info)
        }
        transport.onPeerLost = { [weak self] peerID in
            self?.peerLost(peerID)
        }

        switch role {
        case .host:
            publishRoomInfo()
            transport.startHosting()
        case .client:
            transport.startBrowsing()
        }
    }

    func join(roomID: UUID, as player: LobbyPlayer) {
        let hostPeerID: PeerID? = stateQueue.sync {
            joinedRoomID = roomID
            lobbyPlayer = player
            return discoveredRooms.values.first(where: { $0.id == roomID })?.peerID
        }
        if let hostPeerID {
            transport.invite(hostPeerID)
        }
    }

    func leaveRoom() {
        stateQueue.sync {
            joinedRoomID = nil
            lobbyPlayer = nil
            _lobby = nil
            _gameState = nil
            discoveredHostPeerID = configuredHostPeerID
        }
        transport.disconnect()
    }

    deinit {
        transport.stop()
    }

    func submit(intent: GameIntent, playerID: UUID) throws {
        guard case .client = role else {
            throw GameSessionError.hostCannotSubmitIntent
        }
        let resolvedHostPeerID = stateQueue.sync { configuredHostPeerID ?? discoveredHostPeerID }
        guard let hostPeerID = resolvedHostPeerID else {
            throw GameSessionError.hostNotConnected
        }

        let message = NetworkMessage.intent(playerID: playerID, intent: intent)
        let data = try encoder.encode(message)
        try transport.send(data: data, to: hostPeerID)
    }

    func send(intent: GameIntent, playerID: UUID) throws {
        try submit(intent: intent, playerID: playerID)
    }

    func submitLocal(intent: GameIntent, playerID: UUID) throws {
        guard case .host = role else {
            throw GameSessionError.hostCannotSubmitIntent
        }

        let outcome: Result<GameState, GameRuleError> = stateQueue.sync {
            guard let state = _gameState else {
                return .failure(.playerNotFound(playerID))
            }

            do {
                let updatedState = try apply(intent, submittedBy: playerID, isHost: true, in: state)
                _gameState = updatedState
                return .success(updatedState)
            } catch let error as GameRuleError {
                return .failure(error)
            } catch {
                preconditionFailure("GameRules threw a non-GameRuleError: \(error)")
            }
        }

        switch outcome {
        case let .success(updatedState):
            let snapshot = try encoder.encode(NetworkMessage.stateSnapshot(updatedState))
            onStateChanged?(updatedState)
            publishRoomInfo()
            try transport.broadcast(data: snapshot)
        case let .failure(error):
            onIntentRejected?(error)
        }
    }

    func updateLobby(_ lobby: Lobby) throws {
        guard case .host = role else {
            throw GameSessionError.onlyHostCanManageLobby
        }
        try stateQueue.sync {
            guard _gameState == nil else {
                throw GameSessionError.gameAlreadyStarted
            }
            _lobby = lobby
        }

        onLobbyChanged?(lobby)
        publishRoomInfo()
        try transport.broadcast(data: try encoder.encode(NetworkMessage.lobbySnapshot(lobby)))
    }

    func startGame(with state: GameState) throws {
        guard case .host = role else {
            throw GameSessionError.onlyHostCanManageLobby
        }
        try stateQueue.sync {
            guard _gameState == nil else {
                throw GameSessionError.gameAlreadyStarted
            }
            _gameState = state
            _lobby = nil
        }

        onStateChanged?(state)
        publishRoomInfo()
        try transport.broadcast(data: try encoder.encode(NetworkMessage.stateSnapshot(state)))
    }

    // Clients only hold a connection to the host, so proximity signals between
    // two clients are relayed by the host as a broadcast; each device keeps only
    // the signals addressed to its own player.
    func sendProximitySignal(_ signal: ProximitySignal) throws {
        let data = try encoder.encode(NetworkMessage.proximitySignal(signal))

        switch role {
        case .host:
            try transport.broadcast(data: data)
        case .client:
            let resolvedHostPeerID = stateQueue.sync { configuredHostPeerID ?? discoveredHostPeerID }
            guard let hostPeerID = resolvedHostPeerID else {
                throw GameSessionError.hostNotConnected
            }
            try transport.send(data: data, to: hostPeerID)
        }
    }

    private func peerConnected(_ peerID: PeerID) {
        let (state, lobby, hostPeerID, lobbyPlayer) = stateQueue.sync {
            connectedPeerIDs.insert(peerID)
            if case .client = role, discoveredHostPeerID == nil {
                discoveredHostPeerID = peerID
            }
            return (_gameState, _lobby, configuredHostPeerID ?? discoveredHostPeerID, self.lobbyPlayer)
        }

        do {
            switch role {
            case .host:
                if let state {
                    try transport.send(data: try encoder.encode(NetworkMessage.stateSnapshot(state)), to: peerID)
                } else if let lobby {
                    try transport.send(data: try encoder.encode(NetworkMessage.lobbySnapshot(lobby)), to: peerID)
                }
            case .client:
                guard peerID == hostPeerID else {
                    break
                }
                onHostConnectionChanged?(true)
                if let lobbyPlayer {
                    try transport.send(data: try encoder.encode(NetworkMessage.joinLobby(lobbyPlayer)), to: peerID)
                }
            }
        } catch {
            onTransportError?(error)
        }
    }

    private func peerDisconnected(_ peerID: PeerID) {
        let (updatedLobby, lostHost): (Lobby?, Bool) = stateQueue.sync {
            connectedPeerIDs.remove(peerID)
            let lostHost = role == .client && (configuredHostPeerID ?? discoveredHostPeerID) == peerID
            if discoveredHostPeerID == peerID {
                discoveredHostPeerID = nil
            }

            // Only a lobby drops players who leave; once the game started their
            // player stays so they can rejoin and pick it again.
            guard case .host = role,
                  var lobby = _lobby,
                  let playerIDs = lobbyPlayerIDsByPeer.removeValue(forKey: peerID) else {
                return (nil, lostHost)
            }
            lobby.players.removeAll { playerIDs.contains($0.id) }
            _lobby = lobby
            return (lobby, lostHost)
        }

        if lostHost {
            onHostConnectionChanged?(false)
        }
        guard let updatedLobby else {
            return
        }
        onLobbyChanged?(updatedLobby)
        publishRoomInfo()
        do {
            try transport.broadcast(data: try encoder.encode(NetworkMessage.lobbySnapshot(updatedLobby)))
        } catch {
            onTransportError?(error)
        }
    }

    private func receive(data: Data, from peerID: PeerID) {
        do {
            let message = try decoder.decode(NetworkMessage.self, from: data)
            switch role {
            case .host:
                try handleAsHost(message, from: peerID)
            case .client:
                handleAsClient(message)
            }
        } catch {
            onTransportError?(error)
        }
    }

    private func handleAsHost(_ message: NetworkMessage, from peerID: PeerID) throws {
        if case let .proximitySignal(signal) = message {
            onProximitySignal?(signal)
            try transport.broadcast(data: try encoder.encode(message))
            return
        }
        if case let .joinLobby(player) = message {
            try handleJoinLobby(player, from: peerID)
            return
        }
        guard case let .intent(playerID, intent) = message else {
            return
        }

        // Applying the intent and updating gameState happen atomically under
        // stateQueue so a concurrent intent from another peer can't interleave
        // with this one (e.g. both reading the same pre-update state).
        let outcome: Result<GameState, GameRuleError> = stateQueue.sync {
            guard let state = _gameState else {
                return .failure(.playerNotFound(playerID))
            }
            do {
                let updatedState = try apply(intent, submittedBy: playerID, isHost: false, in: state)
                _gameState = updatedState
                return .success(updatedState)
            } catch let error as GameRuleError {
                return .failure(error)
            } catch {
                preconditionFailure("GameRules threw a non-GameRuleError: \(error)")
            }
        }

        switch outcome {
        case let .success(updatedState):
            let snapshot = try encoder.encode(NetworkMessage.stateSnapshot(updatedState))
            onStateChanged?(updatedState)
            publishRoomInfo()
            try transport.broadcast(data: snapshot)
        case let .failure(error):
            do {
                let rejection = try encoder.encode(NetworkMessage.intentRejected(error))
                try transport.send(data: rejection, to: peerID)
            } catch {
                onTransportError?(error)
            }
        }
    }

    private func handleAsClient(_ message: NetworkMessage) {
        switch message {
        case let .stateSnapshot(state):
            stateQueue.sync {
                _gameState = state
                _lobby = nil
                _lastIntentRejection = nil
            }
            onStateChanged?(state)
        case let .lobbySnapshot(lobby):
            stateQueue.sync { _lobby = lobby }
            onLobbyChanged?(lobby)
        case let .intentRejected(error):
            stateQueue.sync { _lastIntentRejection = error }
            onIntentRejected?(error)
        case let .proximitySignal(signal):
            onProximitySignal?(signal)
        case .intent, .joinLobby:
            break
        }
    }

    private func handleJoinLobby(_ player: LobbyPlayer, from peerID: PeerID) throws {
        let updatedLobby: Lobby? = stateQueue.sync {
            guard var lobby = _lobby else {
                return nil
            }

            let remotePlayer = LobbyPlayer(id: player.id, name: player.name, isHostControlled: false)
            if let index = lobby.players.firstIndex(where: { $0.id == player.id }) {
                lobby.players[index] = remotePlayer
            } else {
                lobby.players.append(remotePlayer)
            }
            lobbyPlayerIDsByPeer[peerID, default: []].insert(player.id)
            _lobby = lobby
            return lobby
        }

        guard let updatedLobby else {
            return
        }
        onLobbyChanged?(updatedLobby)
        publishRoomInfo()
        try transport.broadcast(data: try encoder.encode(NetworkMessage.lobbySnapshot(updatedLobby)))
    }

    private func publishRoomInfo() {
        guard case .host = role else {
            return
        }

        let (state, lobby) = stateQueue.sync { (_gameState, _lobby) }
        let players = state?.players.map(\.name) ?? lobby?.players.map(\.name) ?? []
        let hostName = state?.players.first(where: { $0.id == hostPlayerID })?.name
            ?? lobby?.players.first(where: { $0.id == hostPlayerID })?.name
            ?? ""
        transport.updateDiscoveryInfo(DiscoveredRoom.discoveryInfo(
            roomID: roomID,
            name: hostName.trimmingCharacters(in: .whitespacesAndNewlines),
            playerCount: players.count,
            phase: state == nil ? .lobby : .playing,
            round: state?.round ?? 1,
            mode: state?.mode ?? lobby?.gameMode ?? .classic
        ))
    }

    private func peerFound(_ peerID: PeerID, info: [String: String]) {
        guard case .client = role, let room = DiscoveredRoom(peerID: peerID, discoveryInfo: info) else {
            return
        }

        let (rooms, shouldRejoin) = stateQueue.sync {
            discoveredRooms[peerID] = room
            // A host that restarts (e.g. after the app was closed) comes back as a new
            // peer with the same room ID; reconnect to it without asking again.
            let shouldRejoin = room.id == joinedRoomID && discoveredHostPeerID == nil
            return (sortedRooms(), shouldRejoin)
        }
        onRoomsChanged?(rooms)
        if shouldRejoin {
            transport.invite(peerID)
        }
    }

    private func peerLost(_ peerID: PeerID) {
        guard case .client = role else {
            return
        }
        let rooms = stateQueue.sync {
            discoveredRooms[peerID] = nil
            return sortedRooms()
        }
        onRoomsChanged?(rooms)
    }

    private func sortedRooms() -> [DiscoveredRoom] {
        discoveredRooms.values.sorted {
            ($0.name.localizedLowercase, $0.id.uuidString) < ($1.name.localizedLowercase, $1.id.uuidString)
        }
    }

    private func apply(
        _ intent: GameIntent,
        submittedBy playerID: UUID,
        isHost: Bool,
        in state: GameState
    ) throws -> GameState {
        try GameRules.requireGameNotFinished(in: state)
        if intent.requiresTurn {
            try GameRules.requireTurn(in: state, playerID: playerID)
        }

        switch intent {
        case let .buyProperty(_, propertyID):
            return try GameRules.buyProperty(in: state, playerID: playerID, propertyID: propertyID)
        case let .resolveAuction(propertyID, bids):
            return try GameRules.resolveAuction(in: state, propertyID: propertyID, bids: bids)
        case let .collectRent(_, propertyID):
            return try GameRules.collectRent(in: state, from: playerID, propertyID: propertyID).state
        case let .payTax(_, amount):
            return try GameRules.payTax(in: state, playerID: playerID, amount: amount)
        case let .payTravel(_, route):
            return try GameRules.payTravel(in: state, playerID: playerID, route: route)
        case .collectFreeParking:
            return try GameRules.collectFreeParking(in: state, playerID: playerID)
        case let .collectSalary(_, amount, postponedLoanIDs):
            return try GameRules.collectSalary(
                in: state,
                playerID: playerID,
                amount: amount,
                postponedLoanIDs: postponedLoanIDs
            )
        case let .levelUp(propertyID, _):
            return try GameRules.levelUp(in: state, propertyID: propertyID, playerID: playerID)
        case let .levelDown(propertyID, _):
            return try GameRules.levelDown(in: state, propertyID: propertyID, playerID: playerID)
        case let .mortgageProperty(propertyID, _):
            return try GameRules.mortgageProperty(in: state, propertyID: propertyID, playerID: playerID)
        case let .unmortgageProperty(propertyID, _):
            return try GameRules.unmortgageProperty(in: state, propertyID: propertyID, playerID: playerID)
        case let .declareBankruptcy(_, creditor):
            return try GameRules.declareBankruptcy(in: state, playerID: playerID, creditor: creditor)
        case let .proposeDeal(deal):
            return try GameRules.proposeDeal(in: state, deal: deal, proposerID: playerID)
        case let .acceptDeal(dealID):
            return try GameRules.acceptDeal(in: state, dealID: dealID, playerID: playerID)
        case let .rejectDeal(dealID):
            return try GameRules.rejectDeal(in: state, dealID: dealID, playerID: playerID)
        case let .transferMoney(_, recipientID, amount):
            return try GameRules.transferMoney(in: state, from: playerID, to: recipientID, amount: amount)
        case let .borrowOnCreditCard(_, amount, installments):
            return try GameRules.borrowOnCreditCard(
                in: state,
                playerID: playerID,
                amount: amount,
                installments: installments
            )
        case let .payCreditCard(_, loanID, amount):
            return try GameRules.payCreditCard(in: state, playerID: playerID, loanID: loanID, amount: amount)
        case .endTurn:
            return try GameRules.endTurn(in: state, playerID: playerID)
        case .skipTurn:
            guard isHost else {
                throw GameRuleError.onlyHostCanSkipTurn
            }
            return GameRules.advanceTurn(in: state)
        case .acknowledgeRole:
            return try GameRules.acknowledgeRole(in: state, playerID: playerID)
        case .drawLifeCard:
            var generator = SystemRandomNumberGenerator()
            return try GameRules.drawLifeCard(in: state, playerID: playerID, using: &generator)
        case let .resolveLifeCardDecision(_, accept):
            return try GameRules.resolveLifeCardDecision(in: state, playerID: playerID, accept: accept)
        }
    }
}
