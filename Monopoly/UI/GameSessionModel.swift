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

    let proximity = ProximityPaymentCoordinator()

    private let session: GameSession

    var isProximityPaymentEnabled: Bool {
        gameState?.proximityPaymentsEnabled == true
    }

    var areCreditCardsEnabled: Bool {
        gameState?.activeHouseRules.contains(.creditCards) == true
    }

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

    func collectSalary(amount: Int) {
        guard let localPlayerID else {
            alertMessage = "Selecciona tu jugador antes de cobrar salario."
            return
        }

        send(.collectSalary(playerID: localPlayerID, amount: amount))
    }

    func transfer(to recipientID: UUID, amount: Int) {
        guard let localPlayerID else {
            alertMessage = "Selecciona tu jugador antes de pagar a otro jugador."
            return
        }

        send(.transferMoney(payerID: localPlayerID, recipientID: recipientID, amount: amount))
    }

    func borrowOnCreditCard(amount: Int) {
        guard let localPlayerID else {
            alertMessage = "Selecciona tu jugador antes de pedir un préstamo."
            return
        }

        send(.borrowOnCreditCard(playerID: localPlayerID, amount: amount))
    }

    func payCreditCard(amount: Int) {
        guard let localPlayerID else {
            alertMessage = "Selecciona tu jugador antes de pagar la tarjeta."
            return
        }

        send(.payCreditCard(playerID: localPlayerID, amount: amount))
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
