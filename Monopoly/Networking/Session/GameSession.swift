import Foundation

enum GameSessionError: Error, Equatable {
    case hostCannotSubmitIntent
    case hostNotConnected
    case hostRequiresInitialState
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

    var onStateChanged: ((GameState) -> Void)?
    var onIntentRejected: ((GameRuleError) -> Void)?
    var onTransportError: ((Error) -> Void)?
    var onProximitySignal: ((ProximitySignal) -> Void)?

    init(
        transport: GameTransport,
        role: Role,
        initialState: GameState? = nil,
        hostPeerID: PeerID? = nil,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        if case .host = role, initialState == nil {
            preconditionFailure(GameSessionError.hostRequiresInitialState.localizedDescription)
        }

        self.transport = transport
        self.role = role
        self.encoder = encoder
        self.decoder = decoder
        self.configuredHostPeerID = hostPeerID
        self._gameState = initialState
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

        switch role {
        case .host:
            transport.startHosting()
        case .client:
            transport.startBrowsing()
        }
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
                let updatedState = try apply(intent, submittedBy: playerID, in: state)
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
            try transport.broadcast(data: snapshot)
        case let .failure(error):
            onIntentRejected?(error)
        }
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
        stateQueue.sync {
            connectedPeerIDs.insert(peerID)
            if case .client = role, discoveredHostPeerID == nil {
                discoveredHostPeerID = peerID
            }
        }

        guard case .host = role, let state = gameState else {
            return
        }

        do {
            let snapshot = try encoder.encode(NetworkMessage.stateSnapshot(state))
            try transport.send(data: snapshot, to: peerID)
        } catch {
            onTransportError?(error)
        }
    }

    private func peerDisconnected(_ peerID: PeerID) {
        stateQueue.sync {
            connectedPeerIDs.remove(peerID)
            if discoveredHostPeerID == peerID {
                discoveredHostPeerID = nil
            }
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
                let updatedState = try apply(intent, submittedBy: playerID, in: state)
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
                _lastIntentRejection = nil
            }
            onStateChanged?(state)
        case let .intentRejected(error):
            stateQueue.sync { _lastIntentRejection = error }
            onIntentRejected?(error)
        case let .proximitySignal(signal):
            onProximitySignal?(signal)
        case .intent:
            break
        }
    }

    private func apply(
        _ intent: GameIntent,
        submittedBy playerID: UUID,
        in state: GameState
    ) throws -> GameState {
        switch intent {
        case let .buyProperty(_, propertyID):
            return try GameRules.buyProperty(in: state, playerID: playerID, propertyID: propertyID)
        case let .resolveAuction(propertyID, bids):
            return try GameRules.resolveAuction(in: state, propertyID: propertyID, bids: bids)
        case let .collectRent(_, propertyID):
            return try GameRules.collectRent(in: state, from: playerID, propertyID: propertyID).state
        case let .payTax(_, amount):
            return try GameRules.payTax(in: state, playerID: playerID, amount: amount)
        case let .collectSalary(_, amount):
            return try GameRules.collectSalary(in: state, playerID: playerID, amount: amount)
        case let .buildHouse(propertyID, _):
            return try GameRules.buildHouse(in: state, propertyID: propertyID, playerID: playerID)
        case let .buildHotel(propertyID, _):
            return try GameRules.buildHotel(in: state, propertyID: propertyID, playerID: playerID)
        case let .sellHouse(propertyID, _):
            return try GameRules.sellHouse(in: state, propertyID: propertyID, playerID: playerID)
        case let .mortgageProperty(propertyID, _):
            return try GameRules.mortgageProperty(in: state, propertyID: propertyID, playerID: playerID)
        case let .unmortgageProperty(propertyID, _):
            return try GameRules.unmortgageProperty(in: state, propertyID: propertyID, playerID: playerID)
        case let .declareBankruptcy(_, creditor):
            return try GameRules.declareBankruptcy(in: state, playerID: playerID, creditor: creditor)
        case let .executeTrade(offer):
            let normalizedOffer = TradeOffer(
                fromPlayerID: playerID,
                toPlayerID: offer.toPlayerID,
                offeredPropertyIDs: offer.offeredPropertyIDs,
                offeredMoney: offer.offeredMoney,
                requestedPropertyIDs: offer.requestedPropertyIDs,
                requestedMoney: offer.requestedMoney
            )
            return try GameRules.executeTrade(in: state, offer: normalizedOffer)
        case let .transferMoney(_, recipientID, amount):
            return try GameRules.transferMoney(in: state, from: playerID, to: recipientID, amount: amount)
        case let .borrowOnCreditCard(_, amount):
            return try GameRules.borrowOnCreditCard(in: state, playerID: playerID, amount: amount)
        case let .payCreditCard(_, amount):
            return try GameRules.payCreditCard(in: state, playerID: playerID, amount: amount)
        }
    }
}
