import Foundation

enum GameRuleError: Error, Equatable, Codable {
    case playerNotFound(UUID)
    case propertyNotFound(UUID)
    case insufficientFunds(playerID: UUID, required: Int, available: Int)
    case propertyAlreadyOwned(propertyID: UUID, ownerID: UUID)
    case propertyNotOwnedByPlayer(propertyID: UUID, playerID: UUID)
    case propertyHasNoOwner(UUID)
    case propertyHasNoBuildings(UUID)
    case propertyHasBuildings(UUID)
    case propertyIsMortgaged(UUID)
    case propertyAlreadyMortgaged(UUID)
    case propertyIsNotMortgaged(UUID)
    case playerDoesNotOwnMonopoly(ColorGroup)
    case propertyHasMaximumHouses(UUID)
    case propertyMustHaveFourHouses(UUID)
    case propertyAlreadyHasHotel(UUID)
    case violatesUniformConstruction(UUID)
    case invalidRentTable(UUID)
    case playerIsBankrupt(UUID)
    case invalidDebtAmount(Int)
    case invalidBankruptcyCreditor(UUID)
    case invalidAmount(Int)
    case auctionsDisabled
    case invalidBid
    case transferParticipantsMustDiffer
    case creditCardsDisabled
    case creditLimitExceeded(requested: Int, available: Int)
    case invalidInstallments(Int)
    case creditCardLoanNotFound(UUID)
    case noPostponementsLeft(UUID)
    case notPlayersTurn(currentPlayerID: UUID)
    case onlyHostCanSkipTurn
    case dealNotFound(UUID)
    case notDealParticipant(UUID)
    case invalidDeal
    case notEnoughShares(propertyID: UUID, playerID: UUID)
    case cannotAcceptOwnOffer

    private enum CodingKeys: String, CodingKey {
        case code
        case playerID
        case propertyID
        case ownerID
        case required
        case available
        case colorGroup
        case amount
        case creditorID
        case requested
        case installments
        case loanID
        case dealID
    }

    private enum Code: String, Codable {
        case playerNotFound
        case propertyNotFound
        case insufficientFunds
        case propertyAlreadyOwned
        case propertyNotOwnedByPlayer
        case propertyHasNoOwner
        case propertyHasNoBuildings
        case propertyHasBuildings
        case propertyIsMortgaged
        case propertyAlreadyMortgaged
        case propertyIsNotMortgaged
        case playerDoesNotOwnMonopoly
        case propertyHasMaximumHouses
        case propertyMustHaveFourHouses
        case propertyAlreadyHasHotel
        case violatesUniformConstruction
        case invalidRentTable
        case playerIsBankrupt
        case invalidDebtAmount
        case invalidBankruptcyCreditor
        case invalidAmount
        case auctionsDisabled
        case invalidBid
        case transferParticipantsMustDiffer
        case creditCardsDisabled
        case creditLimitExceeded
        case invalidInstallments
        case creditCardLoanNotFound
        case noPostponementsLeft
        case notPlayersTurn
        case onlyHostCanSkipTurn
        case dealNotFound
        case notDealParticipant
        case invalidDeal
        case notEnoughShares
        case cannotAcceptOwnOffer
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let code = try container.decode(Code.self, forKey: .code)

        switch code {
        case .playerNotFound:
            self = .playerNotFound(try container.decode(UUID.self, forKey: .playerID))
        case .propertyNotFound:
            self = .propertyNotFound(try container.decode(UUID.self, forKey: .propertyID))
        case .insufficientFunds:
            self = .insufficientFunds(
                playerID: try container.decode(UUID.self, forKey: .playerID),
                required: try container.decode(Int.self, forKey: .required),
                available: try container.decode(Int.self, forKey: .available)
            )
        case .propertyAlreadyOwned:
            self = .propertyAlreadyOwned(
                propertyID: try container.decode(UUID.self, forKey: .propertyID),
                ownerID: try container.decode(UUID.self, forKey: .ownerID)
            )
        case .propertyNotOwnedByPlayer:
            self = .propertyNotOwnedByPlayer(
                propertyID: try container.decode(UUID.self, forKey: .propertyID),
                playerID: try container.decode(UUID.self, forKey: .playerID)
            )
        case .propertyHasNoOwner:
            self = .propertyHasNoOwner(try container.decode(UUID.self, forKey: .propertyID))
        case .propertyHasNoBuildings:
            self = .propertyHasNoBuildings(try container.decode(UUID.self, forKey: .propertyID))
        case .propertyHasBuildings:
            self = .propertyHasBuildings(try container.decode(UUID.self, forKey: .propertyID))
        case .propertyIsMortgaged:
            self = .propertyIsMortgaged(try container.decode(UUID.self, forKey: .propertyID))
        case .propertyAlreadyMortgaged:
            self = .propertyAlreadyMortgaged(try container.decode(UUID.self, forKey: .propertyID))
        case .propertyIsNotMortgaged:
            self = .propertyIsNotMortgaged(try container.decode(UUID.self, forKey: .propertyID))
        case .playerDoesNotOwnMonopoly:
            self = .playerDoesNotOwnMonopoly(try container.decode(ColorGroup.self, forKey: .colorGroup))
        case .propertyHasMaximumHouses:
            self = .propertyHasMaximumHouses(try container.decode(UUID.self, forKey: .propertyID))
        case .propertyMustHaveFourHouses:
            self = .propertyMustHaveFourHouses(try container.decode(UUID.self, forKey: .propertyID))
        case .propertyAlreadyHasHotel:
            self = .propertyAlreadyHasHotel(try container.decode(UUID.self, forKey: .propertyID))
        case .violatesUniformConstruction:
            self = .violatesUniformConstruction(try container.decode(UUID.self, forKey: .propertyID))
        case .invalidRentTable:
            self = .invalidRentTable(try container.decode(UUID.self, forKey: .propertyID))
        case .playerIsBankrupt:
            self = .playerIsBankrupt(try container.decode(UUID.self, forKey: .playerID))
        case .invalidDebtAmount:
            self = .invalidDebtAmount(try container.decode(Int.self, forKey: .amount))
        case .invalidBankruptcyCreditor:
            self = .invalidBankruptcyCreditor(try container.decode(UUID.self, forKey: .creditorID))
        case .invalidAmount:
            self = .invalidAmount(try container.decode(Int.self, forKey: .amount))
        case .auctionsDisabled:
            self = .auctionsDisabled
        case .invalidBid:
            self = .invalidBid
        case .transferParticipantsMustDiffer:
            self = .transferParticipantsMustDiffer
        case .creditCardsDisabled:
            self = .creditCardsDisabled
        case .creditLimitExceeded:
            self = .creditLimitExceeded(
                requested: try container.decode(Int.self, forKey: .requested),
                available: try container.decode(Int.self, forKey: .available)
            )
        case .invalidInstallments:
            self = .invalidInstallments(try container.decode(Int.self, forKey: .installments))
        case .creditCardLoanNotFound:
            self = .creditCardLoanNotFound(try container.decode(UUID.self, forKey: .loanID))
        case .noPostponementsLeft:
            self = .noPostponementsLeft(try container.decode(UUID.self, forKey: .loanID))
        case .notPlayersTurn:
            self = .notPlayersTurn(currentPlayerID: try container.decode(UUID.self, forKey: .playerID))
        case .onlyHostCanSkipTurn:
            self = .onlyHostCanSkipTurn
        case .dealNotFound:
            self = .dealNotFound(try container.decode(UUID.self, forKey: .dealID))
        case .notDealParticipant:
            self = .notDealParticipant(try container.decode(UUID.self, forKey: .playerID))
        case .invalidDeal:
            self = .invalidDeal
        case .notEnoughShares:
            self = .notEnoughShares(
                propertyID: try container.decode(UUID.self, forKey: .propertyID),
                playerID: try container.decode(UUID.self, forKey: .playerID)
            )
        case .cannotAcceptOwnOffer:
            self = .cannotAcceptOwnOffer
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .playerNotFound(playerID):
            try container.encode(Code.playerNotFound, forKey: .code)
            try container.encode(playerID, forKey: .playerID)
        case let .propertyNotFound(propertyID):
            try container.encode(Code.propertyNotFound, forKey: .code)
            try container.encode(propertyID, forKey: .propertyID)
        case let .insufficientFunds(playerID, required, available):
            try container.encode(Code.insufficientFunds, forKey: .code)
            try container.encode(playerID, forKey: .playerID)
            try container.encode(required, forKey: .required)
            try container.encode(available, forKey: .available)
        case let .propertyAlreadyOwned(propertyID, ownerID):
            try container.encode(Code.propertyAlreadyOwned, forKey: .code)
            try container.encode(propertyID, forKey: .propertyID)
            try container.encode(ownerID, forKey: .ownerID)
        case let .propertyNotOwnedByPlayer(propertyID, playerID):
            try container.encode(Code.propertyNotOwnedByPlayer, forKey: .code)
            try container.encode(propertyID, forKey: .propertyID)
            try container.encode(playerID, forKey: .playerID)
        case let .propertyHasNoOwner(propertyID):
            try container.encode(Code.propertyHasNoOwner, forKey: .code)
            try container.encode(propertyID, forKey: .propertyID)
        case let .propertyHasNoBuildings(propertyID):
            try container.encode(Code.propertyHasNoBuildings, forKey: .code)
            try container.encode(propertyID, forKey: .propertyID)
        case let .propertyHasBuildings(propertyID):
            try container.encode(Code.propertyHasBuildings, forKey: .code)
            try container.encode(propertyID, forKey: .propertyID)
        case let .propertyIsMortgaged(propertyID):
            try container.encode(Code.propertyIsMortgaged, forKey: .code)
            try container.encode(propertyID, forKey: .propertyID)
        case let .propertyAlreadyMortgaged(propertyID):
            try container.encode(Code.propertyAlreadyMortgaged, forKey: .code)
            try container.encode(propertyID, forKey: .propertyID)
        case let .propertyIsNotMortgaged(propertyID):
            try container.encode(Code.propertyIsNotMortgaged, forKey: .code)
            try container.encode(propertyID, forKey: .propertyID)
        case let .playerDoesNotOwnMonopoly(colorGroup):
            try container.encode(Code.playerDoesNotOwnMonopoly, forKey: .code)
            try container.encode(colorGroup, forKey: .colorGroup)
        case let .propertyHasMaximumHouses(propertyID):
            try container.encode(Code.propertyHasMaximumHouses, forKey: .code)
            try container.encode(propertyID, forKey: .propertyID)
        case let .propertyMustHaveFourHouses(propertyID):
            try container.encode(Code.propertyMustHaveFourHouses, forKey: .code)
            try container.encode(propertyID, forKey: .propertyID)
        case let .propertyAlreadyHasHotel(propertyID):
            try container.encode(Code.propertyAlreadyHasHotel, forKey: .code)
            try container.encode(propertyID, forKey: .propertyID)
        case let .violatesUniformConstruction(propertyID):
            try container.encode(Code.violatesUniformConstruction, forKey: .code)
            try container.encode(propertyID, forKey: .propertyID)
        case let .invalidRentTable(propertyID):
            try container.encode(Code.invalidRentTable, forKey: .code)
            try container.encode(propertyID, forKey: .propertyID)
        case let .playerIsBankrupt(playerID):
            try container.encode(Code.playerIsBankrupt, forKey: .code)
            try container.encode(playerID, forKey: .playerID)
        case let .invalidDebtAmount(amount):
            try container.encode(Code.invalidDebtAmount, forKey: .code)
            try container.encode(amount, forKey: .amount)
        case let .invalidBankruptcyCreditor(creditorID):
            try container.encode(Code.invalidBankruptcyCreditor, forKey: .code)
            try container.encode(creditorID, forKey: .creditorID)
        case let .invalidAmount(amount):
            try container.encode(Code.invalidAmount, forKey: .code)
            try container.encode(amount, forKey: .amount)
        case .auctionsDisabled:
            try container.encode(Code.auctionsDisabled, forKey: .code)
        case .invalidBid:
            try container.encode(Code.invalidBid, forKey: .code)
        case .transferParticipantsMustDiffer:
            try container.encode(Code.transferParticipantsMustDiffer, forKey: .code)
        case .creditCardsDisabled:
            try container.encode(Code.creditCardsDisabled, forKey: .code)
        case let .creditLimitExceeded(requested, available):
            try container.encode(Code.creditLimitExceeded, forKey: .code)
            try container.encode(requested, forKey: .requested)
            try container.encode(available, forKey: .available)
        case let .invalidInstallments(installments):
            try container.encode(Code.invalidInstallments, forKey: .code)
            try container.encode(installments, forKey: .installments)
        case let .creditCardLoanNotFound(loanID):
            try container.encode(Code.creditCardLoanNotFound, forKey: .code)
            try container.encode(loanID, forKey: .loanID)
        case let .noPostponementsLeft(loanID):
            try container.encode(Code.noPostponementsLeft, forKey: .code)
            try container.encode(loanID, forKey: .loanID)
        case let .notPlayersTurn(currentPlayerID):
            try container.encode(Code.notPlayersTurn, forKey: .code)
            try container.encode(currentPlayerID, forKey: .playerID)
        case .onlyHostCanSkipTurn:
            try container.encode(Code.onlyHostCanSkipTurn, forKey: .code)
        case let .dealNotFound(dealID):
            try container.encode(Code.dealNotFound, forKey: .code)
            try container.encode(dealID, forKey: .dealID)
        case let .notDealParticipant(playerID):
            try container.encode(Code.notDealParticipant, forKey: .code)
            try container.encode(playerID, forKey: .playerID)
        case .invalidDeal:
            try container.encode(Code.invalidDeal, forKey: .code)
        case let .notEnoughShares(propertyID, playerID):
            try container.encode(Code.notEnoughShares, forKey: .code)
            try container.encode(propertyID, forKey: .propertyID)
            try container.encode(playerID, forKey: .playerID)
        case .cannotAcceptOwnOffer:
            try container.encode(Code.cannotAcceptOwnOffer, forKey: .code)
        }
    }
}
