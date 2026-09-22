import Foundation

enum GameRuleError: Error, Equatable {
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
}
