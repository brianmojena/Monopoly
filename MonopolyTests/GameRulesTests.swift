import XCTest
@testable import Monopoly

final class GameRulesTests: XCTestCase {
    func testBuyPropertySuccessfullyTransfersMoneyAndOwnership() throws {
        let player = Player(name: "Ana", balance: 200)
        let property = Property(name: "Test Property", colorGroup: .brown, purchasePrice: 100, mortgageValue: 50, baseRent: 10)
        let state = GameState(players: [player], properties: [property])

        let result = try GameRules.buyProperty(in: state, playerID: player.id, propertyID: property.id)

        XCTAssertEqual(result.players[0].balance, 100)
        XCTAssertEqual(result.players[0].propertyIDs, [property.id])
        XCTAssertEqual(result.properties[0].ownerID, player.id)
    }

    func testBuyPropertyFailsWhenBalanceIsInsufficient() {
        let player = Player(name: "Ana", balance: 99)
        let property = Property(name: "Test Property", colorGroup: .brown, purchasePrice: 100, mortgageValue: 50, baseRent: 10)
        let state = GameState(players: [player], properties: [property])

        XCTAssertThrowsError(try GameRules.buyProperty(in: state, playerID: player.id, propertyID: property.id)) { error in
            XCTAssertEqual(
                error as? GameRuleError,
                .insufficientFunds(playerID: player.id, required: 100, available: 99)
            )
        }
    }

    func testBuyPropertyFailsWhenPropertyAlreadyHasOwner() {
        let buyer = Player(name: "Ana", balance: 200)
        let owner = Player(name: "Luis", balance: 200)
        let property = Property(name: "Test Property", colorGroup: .brown, purchasePrice: 100, mortgageValue: 50, baseRent: 10, ownerID: owner.id)
        let state = GameState(players: [buyer, owner], properties: [property])

        XCTAssertThrowsError(try GameRules.buyProperty(in: state, playerID: buyer.id, propertyID: property.id)) { error in
            XCTAssertEqual(error as? GameRuleError, .propertyAlreadyOwned(propertyID: property.id, ownerID: owner.id))
        }
    }

    func testCollectRentSuccessfullyTransfersBaseRent() throws {
        let payer = Player(name: "Ana", balance: 100)
        let owner = Player(name: "Luis", balance: 50)
        let property = Property(name: "Test Property", colorGroup: .brown, purchasePrice: 100, mortgageValue: 50, baseRent: 20, ownerID: owner.id)
        let state = GameState(players: [payer, owner], properties: [property])

        let result = try GameRules.collectRent(in: state, from: payer.id, propertyID: property.id)

        XCTAssertEqual(result.amount, 20)
        XCTAssertEqual(result.state.players[0].balance, 80)
        XCTAssertEqual(result.state.players[1].balance, 70)
    }

    func testCollectRentFailsWhenPayerBalanceIsInsufficient() {
        let payer = Player(name: "Ana", balance: 19)
        let owner = Player(name: "Luis", balance: 50)
        let property = Property(name: "Test Property", colorGroup: .brown, purchasePrice: 100, mortgageValue: 50, baseRent: 20, ownerID: owner.id)
        let state = GameState(players: [payer, owner], properties: [property])

        XCTAssertThrowsError(try GameRules.collectRent(in: state, from: payer.id, propertyID: property.id)) { error in
            XCTAssertEqual(error as? GameRuleError, .insufficientFunds(playerID: payer.id, required: 20, available: 19))
        }
    }

    func testCollectRentDoesNothingForMortgagedProperty() throws {
        let payer = Player(name: "Ana", balance: 100)
        let owner = Player(name: "Luis", balance: 50)
        let property = Property(name: "Test Property", colorGroup: .brown, purchasePrice: 100, mortgageValue: 50, baseRent: 20, ownerID: owner.id, isMortgaged: true)
        let state = GameState(players: [payer, owner], properties: [property])

        let result = try GameRules.collectRent(in: state, from: payer.id, propertyID: property.id)

        XCTAssertEqual(result.amount, 0)
        XCTAssertEqual(result.state.players.map(\.id), state.players.map(\.id))
        XCTAssertEqual(result.state.players.map(\.balance), state.players.map(\.balance))
        XCTAssertEqual(result.state.properties.map(\.isMortgaged), state.properties.map(\.isMortgaged))
    }

    func testCollectRentDoublesWhenOwnerHasCompleteColorGroup() throws {
        let payer = Player(name: "Ana", balance: 100)
        let owner = Player(name: "Luis", balance: 0)
        let firstProperty = Property(name: "First", colorGroup: .brown, purchasePrice: 60, mortgageValue: 30, baseRent: 20, ownerID: owner.id)
        let secondProperty = Property(name: "Second", colorGroup: .brown, purchasePrice: 60, mortgageValue: 30, baseRent: 25, ownerID: owner.id)
        let state = GameState(players: [payer, owner], properties: [firstProperty, secondProperty])

        let result = try GameRules.collectRent(in: state, from: payer.id, propertyID: firstProperty.id)

        XCTAssertEqual(result.amount, 40)
        XCTAssertEqual(result.state.players[0].balance, 60)
        XCTAssertEqual(result.state.players[1].balance, 40)
    }

    func testCollectRentDoesNotDoubleWithoutCompleteColorGroup() throws {
        let payer = Player(name: "Ana", balance: 100)
        let owner = Player(name: "Luis", balance: 0)
        let firstProperty = Property(name: "First", colorGroup: .brown, purchasePrice: 60, mortgageValue: 30, baseRent: 20, ownerID: owner.id)
        let secondProperty = Property(name: "Second", colorGroup: .brown, purchasePrice: 60, mortgageValue: 30, baseRent: 25)
        let state = GameState(players: [payer, owner], properties: [firstProperty, secondProperty])

        let result = try GameRules.collectRent(in: state, from: payer.id, propertyID: firstProperty.id)

        XCTAssertEqual(result.amount, 20)
        XCTAssertEqual(result.state.players[0].balance, 80)
        XCTAssertEqual(result.state.players[1].balance, 20)
    }

    func testCollectRentUsesConstructionLevelTableInsteadOfMonopolyDouble() throws {
        let payer = Player(name: "Ana", balance: 1000)
        let owner = Player(name: "Luis", balance: 0)
        let firstProperty = Property(
            name: "First",
            colorGroup: .brown,
            purchasePrice: 60,
            mortgageValue: 30,
            baseRent: 20,
            rentByConstructionLevel: [20, 100, 300, 500, 700, 900],
            constructionLevel: 5,
            ownerID: owner.id
        )
        let secondProperty = Property(name: "Second", colorGroup: .brown, purchasePrice: 60, mortgageValue: 30, baseRent: 25, ownerID: owner.id)
        let state = GameState(players: [payer, owner], properties: [firstProperty, secondProperty])

        let result = try GameRules.collectRent(in: state, from: payer.id, propertyID: firstProperty.id)

        XCTAssertEqual(result.amount, 900)
        XCTAssertEqual(result.state.players[0].balance, 100)
        XCTAssertEqual(result.state.players[1].balance, 900)
    }

    func testBuildHouseSucceedsWithCompleteColorGroup() throws {
        let owner = Player(name: "Luis", balance: 100)
        let firstProperty = Property(name: "First", colorGroup: .brown, purchasePrice: 60, mortgageValue: 30, baseRent: 20, constructionCost: 50, ownerID: owner.id)
        let secondProperty = Property(name: "Second", colorGroup: .brown, purchasePrice: 60, mortgageValue: 30, baseRent: 25, constructionCost: 50, ownerID: owner.id)
        let state = GameState(players: [owner], properties: [firstProperty, secondProperty])

        let result = try GameRules.buildHouse(in: state, propertyID: firstProperty.id, playerID: owner.id)

        XCTAssertEqual(result.players[0].balance, 50)
        XCTAssertEqual(result.properties[0].constructionLevel, 1)
    }

    func testBuildHouseFailsWithoutCompleteColorGroup() {
        let owner = Player(name: "Luis", balance: 100)
        let firstProperty = Property(name: "First", colorGroup: .brown, purchasePrice: 60, mortgageValue: 30, baseRent: 20, constructionCost: 50, ownerID: owner.id)
        let secondProperty = Property(name: "Second", colorGroup: .brown, purchasePrice: 60, mortgageValue: 30, baseRent: 25, constructionCost: 50)
        let state = GameState(players: [owner], properties: [firstProperty, secondProperty])

        XCTAssertThrowsError(try GameRules.buildHouse(in: state, propertyID: firstProperty.id, playerID: owner.id)) { error in
            XCTAssertEqual(error as? GameRuleError, .playerDoesNotOwnMonopoly(.brown))
        }
    }

    func testBuildHouseFailsWhenBalanceIsInsufficient() {
        let owner = Player(name: "Luis", balance: 49)
        let firstProperty = Property(name: "First", colorGroup: .brown, purchasePrice: 60, mortgageValue: 30, baseRent: 20, constructionCost: 50, ownerID: owner.id)
        let secondProperty = Property(name: "Second", colorGroup: .brown, purchasePrice: 60, mortgageValue: 30, baseRent: 25, constructionCost: 50, ownerID: owner.id)
        let state = GameState(players: [owner], properties: [firstProperty, secondProperty])

        XCTAssertThrowsError(try GameRules.buildHouse(in: state, propertyID: firstProperty.id, playerID: owner.id)) { error in
            XCTAssertEqual(error as? GameRuleError, .insufficientFunds(playerID: owner.id, required: 50, available: 49))
        }
    }

    func testBuildHouseFailsWhenItViolatesUniformConstruction() {
        let owner = Player(name: "Luis", balance: 100)
        let firstProperty = Property(name: "First", colorGroup: .brown, purchasePrice: 60, mortgageValue: 30, baseRent: 20, constructionCost: 50, constructionLevel: 1, ownerID: owner.id)
        let secondProperty = Property(name: "Second", colorGroup: .brown, purchasePrice: 60, mortgageValue: 30, baseRent: 25, constructionCost: 50, ownerID: owner.id)
        let state = GameState(players: [owner], properties: [firstProperty, secondProperty])

        XCTAssertThrowsError(try GameRules.buildHouse(in: state, propertyID: firstProperty.id, playerID: owner.id)) { error in
            XCTAssertEqual(error as? GameRuleError, .violatesUniformConstruction(firstProperty.id))
        }
    }

    func testBuildHotelSucceedsAfterAllPropertiesReachFourHouses() throws {
        let owner = Player(name: "Luis", balance: 50)
        let firstProperty = Property(name: "First", colorGroup: .brown, purchasePrice: 60, mortgageValue: 30, baseRent: 20, constructionCost: 50, constructionLevel: 4, ownerID: owner.id)
        let secondProperty = Property(name: "Second", colorGroup: .brown, purchasePrice: 60, mortgageValue: 30, baseRent: 25, constructionCost: 50, constructionLevel: 4, ownerID: owner.id)
        let state = GameState(players: [owner], properties: [firstProperty, secondProperty])

        let result = try GameRules.buildHotel(in: state, propertyID: firstProperty.id, playerID: owner.id)

        XCTAssertEqual(result.players[0].balance, 0)
        XCTAssertEqual(result.properties[0].constructionLevel, 5)
        XCTAssertEqual(result.properties[1].constructionLevel, 4)
    }

    func testBuildHouseFailsForMortgagedProperty() {
        let owner = Player(name: "Luis", balance: 100)
        let firstProperty = Property(name: "First", colorGroup: .brown, purchasePrice: 60, mortgageValue: 30, baseRent: 20, constructionCost: 50, ownerID: owner.id, isMortgaged: true)
        let secondProperty = Property(name: "Second", colorGroup: .brown, purchasePrice: 60, mortgageValue: 30, baseRent: 25, constructionCost: 50, ownerID: owner.id)
        let state = GameState(players: [owner], properties: [firstProperty, secondProperty])

        XCTAssertThrowsError(try GameRules.buildHouse(in: state, propertyID: firstProperty.id, playerID: owner.id)) { error in
            XCTAssertEqual(error as? GameRuleError, .propertyIsMortgaged(firstProperty.id))
        }
    }

    func testMortgagePropertySuccessfullyAddsMortgageValue() throws {
        let player = Player(name: "Ana", balance: 100)
        let property = Property(name: "Test Property", colorGroup: .brown, purchasePrice: 100, mortgageValue: 50, baseRent: 20, ownerID: player.id)
        let state = GameState(players: [player], properties: [property])

        let result = try GameRules.mortgageProperty(in: state, propertyID: property.id, playerID: player.id)

        XCTAssertEqual(result.players[0].balance, 150)
        XCTAssertTrue(result.properties[0].isMortgaged)
    }

    func testMortgagePropertyFailsWhenPropertyHasBuildings() {
        let player = Player(name: "Ana", balance: 100)
        let property = Property(name: "Test Property", colorGroup: .brown, purchasePrice: 100, mortgageValue: 50, baseRent: 20, constructionLevel: 1, ownerID: player.id)
        let state = GameState(players: [player], properties: [property])

        XCTAssertThrowsError(try GameRules.mortgageProperty(in: state, propertyID: property.id, playerID: player.id)) { error in
            XCTAssertEqual(error as? GameRuleError, .propertyHasBuildings(property.id))
        }
    }

    func testUnmortgagePropertyChargesMortgageValuePlusTenPercentInterest() throws {
        let player = Player(name: "Ana", balance: 66)
        let property = Property(name: "Test Property", colorGroup: .brown, purchasePrice: 100, mortgageValue: 60, baseRent: 20, ownerID: player.id, isMortgaged: true)
        let state = GameState(players: [player], properties: [property])

        let result = try GameRules.unmortgageProperty(in: state, propertyID: property.id, playerID: player.id)

        XCTAssertEqual(result.players[0].balance, 0)
        XCTAssertFalse(result.properties[0].isMortgaged)
    }

    func testUnmortgagePropertyFailsWhenBalanceIsInsufficient() {
        let player = Player(name: "Ana", balance: 65)
        let property = Property(name: "Test Property", colorGroup: .brown, purchasePrice: 100, mortgageValue: 60, baseRent: 20, ownerID: player.id, isMortgaged: true)
        let state = GameState(players: [player], properties: [property])

        XCTAssertThrowsError(try GameRules.unmortgageProperty(in: state, propertyID: property.id, playerID: player.id)) { error in
            XCTAssertEqual(error as? GameRuleError, .insufficientFunds(playerID: player.id, required: 66, available: 65))
        }
    }

    func testSellHouseSuccessfullyCreditsHalfConstructionCost() throws {
        let owner = Player(name: "Luis", balance: 0)
        let firstProperty = Property(
            name: "First",
            colorGroup: .brown,
            purchasePrice: 60,
            mortgageValue: 30,
            baseRent: 20,
            constructionCost: 50,
            constructionLevel: 1,
            ownerID: owner.id
        )
        let secondProperty = Property(
            name: "Second",
            colorGroup: .brown,
            purchasePrice: 60,
            mortgageValue: 30,
            baseRent: 25,
            constructionCost: 50,
            constructionLevel: 1,
            ownerID: owner.id
        )
        let state = GameState(players: [owner], properties: [firstProperty, secondProperty])

        let result = try GameRules.sellHouse(in: state, propertyID: firstProperty.id, playerID: owner.id)

        XCTAssertEqual(result.players[0].balance, 25)
        XCTAssertEqual(result.properties[0].constructionLevel, 0)
    }

    func testSellHotelCreditsHalfHotelCostAndLeavesFourHouses() throws {
        let owner = Player(name: "Luis", balance: 0)
        let hotelProperty = Property(
            name: "Hotel Property",
            colorGroup: .brown,
            purchasePrice: 60,
            mortgageValue: 30,
            baseRent: 20,
            constructionCost: 50,
            constructionLevel: 5,
            ownerID: owner.id
        )
        let otherProperty = Property(
            name: "Other Property",
            colorGroup: .brown,
            purchasePrice: 60,
            mortgageValue: 30,
            baseRent: 25,
            constructionCost: 50,
            constructionLevel: 4,
            ownerID: owner.id
        )
        let state = GameState(players: [owner], properties: [hotelProperty, otherProperty])

        let result = try GameRules.sellHouse(in: state, propertyID: hotelProperty.id, playerID: owner.id)

        XCTAssertEqual(result.players[0].balance, 25)
        XCTAssertEqual(result.properties[0].constructionLevel, 4)
    }

    func testSellHouseFailsWhenItViolatesUniformConstruction() {
        let owner = Player(name: "Luis", balance: 0)
        let firstProperty = Property(name: "First", colorGroup: .brown, purchasePrice: 60, mortgageValue: 30, baseRent: 20, constructionLevel: 1, ownerID: owner.id)
        let secondProperty = Property(name: "Second", colorGroup: .brown, purchasePrice: 60, mortgageValue: 30, baseRent: 25, constructionLevel: 2, ownerID: owner.id)
        let state = GameState(players: [owner], properties: [firstProperty, secondProperty])

        XCTAssertThrowsError(try GameRules.sellHouse(in: state, propertyID: firstProperty.id, playerID: owner.id)) { error in
            XCTAssertEqual(error as? GameRuleError, .violatesUniformConstruction(firstProperty.id))
        }
    }

    func testSellHouseFailsWhenPropertyHasNoBuildings() {
        let owner = Player(name: "Luis", balance: 0)
        let property = Property(name: "First", colorGroup: .brown, purchasePrice: 60, mortgageValue: 30, baseRent: 20, ownerID: owner.id)
        let state = GameState(players: [owner], properties: [property])

        XCTAssertThrowsError(try GameRules.sellHouse(in: state, propertyID: property.id, playerID: owner.id)) { error in
            XCTAssertEqual(error as? GameRuleError, .propertyHasNoBuildings(property.id))
        }
    }

    func testSellHouseFailsWhenPropertyIsNotOwnedByPlayer() {
        let player = Player(name: "Ana", balance: 0)
        let owner = Player(name: "Luis", balance: 0)
        let property = Property(name: "First", colorGroup: .brown, purchasePrice: 60, mortgageValue: 30, baseRent: 20, constructionLevel: 1, ownerID: owner.id)
        let state = GameState(players: [player, owner], properties: [property])

        XCTAssertThrowsError(try GameRules.sellHouse(in: state, propertyID: property.id, playerID: player.id)) { error in
            XCTAssertEqual(error as? GameRuleError, .propertyNotOwnedByPlayer(propertyID: property.id, playerID: player.id))
        }
    }

    func testCanCoverDebtIncludesPotentialMortgagesAndBuildingSales() throws {
        let player = Player(name: "Ana", balance: 20)
        let mortgagableProperty = Property(name: "Mortgageable", colorGroup: .brown, purchasePrice: 100, mortgageValue: 50, baseRent: 10, ownerID: player.id)
        let builtProperty = Property(name: "Built", colorGroup: .lightBlue, purchasePrice: 100, mortgageValue: 50, baseRent: 10, constructionCost: 100, constructionLevel: 1, ownerID: player.id)
        let state = GameState(players: [player], properties: [mortgagableProperty, builtProperty])

        let result = try GameRules.canCoverDebt(
            in: state,
            playerID: player.id,
            debt: Debt(amount: 170, creditor: .bank)
        )

        XCTAssertTrue(result)
    }

    func testCanCoverDebtReturnsFalseWhenLiquidatingEverythingIsInsufficient() throws {
        let player = Player(name: "Ana", balance: 10)
        let property = Property(name: "Property", colorGroup: .brown, purchasePrice: 100, mortgageValue: 30, baseRent: 10, constructionCost: 50, constructionLevel: 1, ownerID: player.id)
        let state = GameState(players: [player], properties: [property])

        let result = try GameRules.canCoverDebt(
            in: state,
            playerID: player.id,
            debt: Debt(amount: 66, creditor: .bank)
        )

        XCTAssertFalse(result)
    }

    func testDeclareBankruptcyTransfersPropertiesAndBalanceToAnotherPlayer() throws {
        let bankrupt = Player(name: "Ana", balance: 40)
        let creditor = Player(name: "Luis", balance: 100)
        let property = Property(
            name: "Property",
            colorGroup: .brown,
            purchasePrice: 100,
            mortgageValue: 50,
            baseRent: 10,
            constructionLevel: 2,
            ownerID: bankrupt.id
        )
        let state = GameState(players: [bankrupt, creditor], properties: [property])

        let result = try GameRules.declareBankruptcy(
            in: state,
            playerID: bankrupt.id,
            creditor: .player(creditor.id)
        )

        XCTAssertEqual(result.players[0].status, .bankrupt)
        XCTAssertEqual(result.players[0].balance, 0)
        XCTAssertEqual(result.players[0].propertyIDs, [])
        XCTAssertEqual(result.players[1].balance, 140)
        XCTAssertEqual(result.players[1].propertyIDs, [property.id])
        XCTAssertEqual(result.properties[0].ownerID, creditor.id)
        XCTAssertEqual(result.properties[0].constructionLevel, 2)
    }

    func testDeclareBankruptcyReturnsPropertiesToBankAndRemovesBalance() throws {
        let bankrupt = Player(name: "Ana", balance: 40)
        let property = Property(
            name: "Property",
            colorGroup: .brown,
            purchasePrice: 100,
            mortgageValue: 50,
            baseRent: 10,
            constructionLevel: 3,
            ownerID: bankrupt.id,
            isMortgaged: false
        )
        let state = GameState(players: [bankrupt], properties: [property])

        let result = try GameRules.declareBankruptcy(
            in: state,
            playerID: bankrupt.id,
            creditor: .bank
        )

        XCTAssertEqual(result.players[0].status, .bankrupt)
        XCTAssertEqual(result.players[0].balance, 0)
        XCTAssertEqual(result.players[0].propertyIDs, [])
        XCTAssertNil(result.properties[0].ownerID)
        XCTAssertEqual(result.properties[0].constructionLevel, 0)
        XCTAssertFalse(result.properties[0].isMortgaged)
    }

    func testBankruptPlayerCannotBuyProperty() throws {
        let player = Player(name: "Ana", balance: 100, status: .bankrupt)
        let property = Property(name: "Property", colorGroup: .brown, purchasePrice: 50, mortgageValue: 25, baseRent: 10)
        let state = GameState(players: [player], properties: [property])

        XCTAssertThrowsError(try GameRules.buyProperty(in: state, playerID: player.id, propertyID: property.id)) { error in
            XCTAssertEqual(error as? GameRuleError, .playerIsBankrupt(player.id))
        }
    }
}
