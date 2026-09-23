import Foundation

/// What a player's QR code asks for (PROJECT_RULES section 3). It only says who or
/// which property gets paid; the payment itself is the usual `GameIntent`, validated
/// by the host like any other.
enum QRPaymentRequest: Equatable {
    case rent(propertyID: UUID)
    /// `amount` is nil when the payer chooses it.
    case transfer(recipientID: UUID, amount: Int?)

    private static let scheme = "monopoly-pay"
    private static let version = "1"

    var payload: String {
        switch self {
        case let .rent(propertyID):
            return [Self.scheme, Self.version, "rent", propertyID.uuidString].joined(separator: ":")
        case let .transfer(recipientID, amount):
            return [Self.scheme, Self.version, "transfer", recipientID.uuidString, String(amount ?? 0)].joined(separator: ":")
        }
    }

    init?(payload: String) {
        let parts = payload.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":").map(String.init)
        guard parts.count >= 4, parts[0] == Self.scheme, parts[1] == Self.version,
              let id = UUID(uuidString: parts[3]) else {
            return nil
        }

        switch (parts[2], parts.count) {
        case ("rent", 4):
            self = .rent(propertyID: id)
        case ("transfer", 5):
            guard let amount = Int(parts[4]), amount >= 0 else {
                return nil
            }
            self = .transfer(recipientID: id, amount: amount == 0 ? nil : amount)
        default:
            return nil
        }
    }
}

/// A scanned QR checked against the current game, ready to confirm.
enum QRPaymentPreview: Equatable {
    case rent(propertyID: UUID, propertyName: String, amount: Int)
    case transfer(recipientID: UUID, recipientName: String, amount: Int?)
}

enum QRPaymentProblem: Error, Equatable {
    case notFromThisGame
    case ownQRCode
    case recipientNotActive(name: String)
    case propertyHasNoOwner(name: String)
    case propertyIsMortgaged(name: String)
    case nothingToPay(name: String)
    case notYourTurn
    case insufficientFunds(required: Int, available: Int)
    case cannotPayRent(name: String)

    var message: String {
        switch self {
        case .notFromThisGame:
            return "Este QR no es de esta partida."
        case .ownQRCode:
            return "Es tu propio QR: pídele el suyo a quien cobra."
        case let .recipientNotActive(name):
            return "\(name) está en bancarrota y no puede cobrar."
        case let .propertyHasNoOwner(name):
            return "\(name) no tiene dueño."
        case let .propertyIsMortgaged(name):
            return "\(name) está hipotecada: no cobra renta."
        case let .nothingToPay(name):
            return "No debes renta en \(name): es toda tuya."
        case .notYourTurn:
            return "La renta solo se paga en tu turno."
        case let .insufficientFunds(required, available):
            return "No te alcanza: hacen falta $\(required) y tienes $\(available)."
        case let .cannotPayRent(name):
            return "Ahora no se puede pagar la renta de \(name)."
        }
    }
}

extension QRPaymentRequest {
    /// Checks the request against the game before the payer confirms. The host
    /// validates the resulting intent again, so this only gives early, clear errors.
    func preview(in state: GameState, payerID: UUID) -> Result<QRPaymentPreview, QRPaymentProblem> {
        switch self {
        case let .transfer(recipientID, amount):
            guard let recipient = state.players.first(where: { $0.id == recipientID }) else {
                return .failure(.notFromThisGame)
            }
            guard recipientID != payerID else {
                return .failure(.ownQRCode)
            }
            guard recipient.status == .active else {
                return .failure(.recipientNotActive(name: recipient.name))
            }
            return .success(.transfer(recipientID: recipientID, recipientName: recipient.name, amount: amount))

        case let .rent(propertyID):
            guard let property = state.properties.first(where: { $0.id == propertyID }) else {
                return .failure(.notFromThisGame)
            }
            guard property.isOwned else {
                return .failure(.propertyHasNoOwner(name: property.name))
            }
            guard !property.isMortgaged else {
                return .failure(.propertyIsMortgaged(name: property.name))
            }
            if let currentPlayerID = state.currentPlayerID, currentPlayerID != payerID {
                return .failure(.notYourTurn)
            }
            do {
                let amount = try GameRules.collectRent(in: state, from: payerID, propertyID: propertyID).amount
                guard amount > 0 else {
                    return .failure(.nothingToPay(name: property.name))
                }
                return .success(.rent(propertyID: propertyID, propertyName: property.name, amount: amount))
            } catch let GameRuleError.insufficientFunds(_, required, available) {
                return .failure(.insufficientFunds(required: required, available: available))
            } catch {
                return .failure(.cannotPayRent(name: property.name))
            }
        }
    }
}
