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

    func testResolveAuctionWithSingleBidTransfersBidAmountAndOwnership() throws {
        let bidder = Player(name: "Ana", balance: 200)
        let property = Property(name: "Test Property", colorGroup: .brown, purchasePrice: 100, mortgageValue: 50, baseRent: 10)
        let state = GameState(players: [bidder], properties: [property])

        let result = try GameRules.resolveAuction(
            in: state,
            propertyID: property.id,
            bids: [AuctionBid(playerID: bidder.id, amount: 75)]
        )

        XCTAssertEqual(result.players[0].balance, 125)
        XCTAssertEqual(result.players[0].propertyIDs, [property.id])
        XCTAssertEqual(result.properties[0].ownerID, bidder.id)
    }

    func testResolveAuctionWithIncreasingBidsChargesHighestBidNotListingPrice() throws {
        let firstBidder = Player(name: "Ana", balance: 200)
        let secondBidder = Player(name: "Luis", balance: 200)
        let property = Property(name: "Test Property", colorGroup: .brown, purchasePrice: 100, mortgageValue: 50, baseRent: 10)
        let state = GameState(players: [firstBidder, secondBidder], properties: [property])

        let result = try GameRules.resolveAuction(
            in: state,
            propertyID: property.id,
            bids: [
                AuctionBid(playerID: firstBidder.id, amount: 40),
                AuctionBid(playerID: secondBidder.id, amount: 125)
            ]
        )

        XCTAssertEqual(result.players[0].balance, 200)
        XCTAssertEqual(result.players[1].balance, 75)
        XCTAssertEqual(result.players[1].propertyIDs, [property.id])
        XCTAssertEqual(result.properties[0].ownerID, secondBidder.id)
    }

    func testResolveAuctionWithNoBidsLeavesStateUnchanged() throws {
        let bidder = Player(name: "Ana", balance: 200)
        let property = Property(name: "Test Property", colorGroup: .brown, purchasePrice: 100, mortgageValue: 50, baseRent: 10)
        let state = GameState(players: [bidder], properties: [property])

        let result = try GameRules.resolveAuction(in: state, propertyID: property.id, bids: [])

        XCTAssertEqual(result, state)
        XCTAssertNil(result.properties[0].ownerID)
    }

    func testResolveAuctionFailsAtomicallyWhenBidDoesNotIncrease() {
        let firstBidder = Player(name: "Ana", balance: 200)
        let secondBidder = Player(name: "Luis", balance: 200)
        let property = Property(name: "Test Property", colorGroup: .brown, purchasePrice: 100, mortgageValue: 50, baseRent: 10)
        let state = GameState(players: [firstBidder, secondBidder], properties: [property])

        XCTAssertThrowsError(
            try GameRules.resolveAuction(
                in: state,
                propertyID: property.id,
                bids: [
                    AuctionBid(playerID: firstBidder.id, amount: 100),
                    AuctionBid(playerID: secondBidder.id, amount: 80)
                ]
            )
        ) { error in
            XCTAssertEqual(error as? GameRuleError, .invalidBid)
        }
        XCTAssertEqual(state, GameState(players: [firstBidder, secondBidder], properties: [property]))
    }

    func testResolveAuctionFailsWhenWinnerCannotCoverBid() {
        let bidder = Player(name: "Ana", balance: 99)
        let property = Property(name: "Test Property", colorGroup: .brown, purchasePrice: 50, mortgageValue: 25, baseRent: 10)
        let state = GameState(players: [bidder], properties: [property])

        XCTAssertThrowsError(
            try GameRules.resolveAuction(
                in: state,
                propertyID: property.id,
                bids: [AuctionBid(playerID: bidder.id, amount: 100)]
            )
        ) { error in
            XCTAssertEqual(
                error as? GameRuleError,
                .insufficientFunds(playerID: bidder.id, required: 100, available: 99)
            )
        }
        XCTAssertEqual(state, GameState(players: [bidder], properties: [property]))
    }

    func testResolveAuctionFailsWhenPropertyAlreadyHasOwner() {
        let bidder = Player(name: "Ana", balance: 200)
        let owner = Player(name: "Luis", balance: 200)
        let property = Property(name: "Test Property", colorGroup: .brown, purchasePrice: 100, mortgageValue: 50, baseRent: 10, ownerID: owner.id)
        let state = GameState(players: [bidder, owner], properties: [property])

        XCTAssertThrowsError(
            try GameRules.resolveAuction(
                in: state,
                propertyID: property.id,
                bids: [AuctionBid(playerID: bidder.id, amount: 100)]
            )
        ) { error in
            XCTAssertEqual(error as? GameRuleError, .propertyAlreadyOwned(propertyID: property.id, ownerID: owner.id))
        }
    }

    func testResolveAuctionFailsWhenAuctionsAreDisabled() {
        let bidder = Player(name: "Ana", balance: 200)
        let property = Property(name: "Test Property", colorGroup: .brown, purchasePrice: 100, mortgageValue: 50, baseRent: 10)
        let state = GameState(players: [bidder], properties: [property], activeHouseRules: [.noAuction])

        XCTAssertThrowsError(
            try GameRules.resolveAuction(
                in: state,
                propertyID: property.id,
                bids: [AuctionBid(playerID: bidder.id, amount: 100)]
            )
        ) { error in
            XCTAssertEqual(error as? GameRuleError, .auctionsDisabled)
        }
    }

    func testResolveAuctionFailsWhenBidderIsBankrupt() {
        let bidder = Player(name: "Ana", balance: 200, status: .bankrupt)
        let property = Property(name: "Test Property", colorGroup: .brown, purchasePrice: 100, mortgageValue: 50, baseRent: 10)
        let state = GameState(players: [bidder], properties: [property])

        XCTAssertThrowsError(
            try GameRules.resolveAuction(
                in: state,
                propertyID: property.id,
                bids: [AuctionBid(playerID: bidder.id, amount: 100)]
            )
        ) { error in
            XCTAssertEqual(error as? GameRuleError, .playerIsBankrupt(bidder.id))
        }
    }

    func testPlayerWhoDeclinedPurchaseCanWinAuction() throws {
        let playerWhoDeclined = Player(name: "Ana", balance: 200)
        let otherPlayer = Player(name: "Luis", balance: 200)
        let property = Property(name: "Test Property", colorGroup: .brown, purchasePrice: 100, mortgageValue: 50, baseRent: 10)
        let state = GameState(players: [playerWhoDeclined, otherPlayer], properties: [property])

        let result = try GameRules.resolveAuction(
            in: state,
            propertyID: property.id,
            bids: [AuctionBid(playerID: otherPlayer.id, amount: 40), AuctionBid(playerID: playerWhoDeclined.id, amount: 60)]
        )

        XCTAssertEqual(result.properties[0].ownerID, playerWhoDeclined.id)
        XCTAssertEqual(result.players[0].propertyIDs, [property.id])
        XCTAssertEqual(result.players[0].balance, 140)
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

    func testPayTaxSuccessfullyRemovesMoneyFromTheGame() throws {
        let payer = Player(name: "Ana", balance: 500)
        let otherPlayer = Player(name: "Luis", balance: 100)
        let state = GameState(players: [payer, otherPlayer], properties: [])

        let result = try GameRules.payTax(in: state, playerID: payer.id, amount: 75)

        XCTAssertEqual(result.players[0].balance, 425)
        XCTAssertEqual(result.players[1].balance, 100)
    }

    func testPayTaxFailsWhenBalanceIsInsufficient() {
        let payer = Player(name: "Ana", balance: 49)
        let state = GameState(players: [payer], properties: [])

        XCTAssertThrowsError(try GameRules.payTax(in: state, playerID: payer.id, amount: 50)) { error in
            XCTAssertEqual(
                error as? GameRuleError,
                .insufficientFunds(playerID: payer.id, required: 50, available: 49)
            )
        }
    }

    func testCollectSalarySuccessfullyCreditsPlayer() throws {
        let player = Player(name: "Ana", balance: 200)
        let state = GameState(players: [player], properties: [])

        let result = try GameRules.collectSalary(in: state, playerID: player.id, amount: 200)

        XCTAssertEqual(result.players[0].balance, 400)
    }

    func testTransferMoneyMovesAmountBetweenPlayers() throws {
        let payer = Player(name: "Ana", balance: 300)
        let recipient = Player(name: "Luis", balance: 100)
        let state = GameState(players: [payer, recipient], properties: [])

        let result = try GameRules.transferMoney(in: state, from: payer.id, to: recipient.id, amount: 50)

        XCTAssertEqual(result.players[0].balance, 250)
        XCTAssertEqual(result.players[1].balance, 150)
    }

    func testTransferMoneyFailsWhenBalanceIsInsufficient() {
        let payer = Player(name: "Ana", balance: 49)
        let recipient = Player(name: "Luis", balance: 100)
        let state = GameState(players: [payer, recipient], properties: [])

        XCTAssertThrowsError(try GameRules.transferMoney(in: state, from: payer.id, to: recipient.id, amount: 50)) { error in
            XCTAssertEqual(
                error as? GameRuleError,
                .insufficientFunds(playerID: payer.id, required: 50, available: 49)
            )
        }
    }

    func testTransferMoneyFailsForNonPositiveAmount() {
        let payer = Player(name: "Ana", balance: 100)
        let recipient = Player(name: "Luis", balance: 100)
        let state = GameState(players: [payer, recipient], properties: [])

        XCTAssertThrowsError(try GameRules.transferMoney(in: state, from: payer.id, to: recipient.id, amount: 0)) { error in
            XCTAssertEqual(error as? GameRuleError, .invalidAmount(0))
        }
    }

    func testTransferMoneyFailsWhenPayingYourself() {
        let payer = Player(name: "Ana", balance: 100)
        let state = GameState(players: [payer], properties: [])

        XCTAssertThrowsError(try GameRules.transferMoney(in: state, from: payer.id, to: payer.id, amount: 10)) { error in
            XCTAssertEqual(error as? GameRuleError, .transferParticipantsMustDiffer)
        }
    }

    func testTransferMoneyFailsWhenRecipientIsBankrupt() {
        let payer = Player(name: "Ana", balance: 100)
        let recipient = Player(name: "Luis", balance: 0, status: .bankrupt)
        let state = GameState(players: [payer, recipient], properties: [])

        XCTAssertThrowsError(try GameRules.transferMoney(in: state, from: payer.id, to: recipient.id, amount: 10)) { error in
            XCTAssertEqual(error as? GameRuleError, .playerIsBankrupt(recipient.id))
        }
    }

    func testNetWorthCountsCashUnmortgagedPropertiesAndBuildingsMinusDebt() throws {
        let loan = CreditCardLoan(remainingDebt: 110, installmentsRemaining: 1, postponementsRemaining: 4)
        let player = Player(name: "Ana", balance: 500, creditCardLoans: [loan])
        let built = Property(name: "Built", colorGroup: .brown, purchasePrice: 100, mortgageValue: 50, baseRent: 10, constructionCost: 50, constructionLevel: 2, ownerID: player.id)
        let mortgaged = Property(name: "Mortgaged", colorGroup: .brown, purchasePrice: 60, mortgageValue: 30, baseRent: 4, ownerID: player.id, isMortgaged: true)
        let state = GameState(players: [player], properties: [built, mortgaged])

        XCTAssertEqual(try GameRules.netWorth(of: player.id, in: state), 500 + 100 + 2 * 50 - 110)
    }

    func testBorrowOnCreditCardCreatesLoanWithInterestInstallmentsAndPostponements() throws {
        let player = Player(name: "Ana", balance: 1000)
        let state = GameState(players: [player], properties: [], activeHouseRules: [.creditCards])

        let result = try GameRules.borrowOnCreditCard(in: state, playerID: player.id, amount: 500, installments: 4)

        XCTAssertEqual(result.players[0].balance, 1500)
        XCTAssertEqual(result.players[0].creditCardLoans.count, 1)
        XCTAssertEqual(result.players[0].creditCardLoans[0].remainingDebt, 550)
        XCTAssertEqual(result.players[0].creditCardLoans[0].installmentsRemaining, 4)
        XCTAssertEqual(result.players[0].creditCardLoans[0].postponementsRemaining, 1)
    }

    func testBorrowOnCreditCardRejectsInstallmentsOutsideOneToFive() {
        let player = Player(name: "Ana", balance: 1000)
        let state = GameState(players: [player], properties: [], activeHouseRules: [.creditCards])

        for installments in [0, 6] {
            XCTAssertThrowsError(try GameRules.borrowOnCreditCard(in: state, playerID: player.id, amount: 100, installments: installments)) { error in
                XCTAssertEqual(error as? GameRuleError, .invalidInstallments(installments))
            }
        }
    }

    func testBorrowOnCreditCardFailsAboveHalfOfNetWorth() {
        let player = Player(name: "Ana", balance: 1000)
        let state = GameState(players: [player], properties: [], activeHouseRules: [.creditCards])

        XCTAssertThrowsError(try GameRules.borrowOnCreditCard(in: state, playerID: player.id, amount: 501, installments: 1)) { error in
            XCTAssertEqual(error as? GameRuleError, .creditLimitExceeded(requested: 501, available: 500))
        }
    }

    func testBorrowOnCreditCardCannotBeChainedPastTheLimit() throws {
        let player = Player(name: "Ana", balance: 1000)
        let state = GameState(players: [player], properties: [], activeHouseRules: [.creditCards])

        let afterLoan = try GameRules.borrowOnCreditCard(in: state, playerID: player.id, amount: 500, installments: 5)

        XCTAssertEqual(try GameRules.availableCredit(for: player.id, in: afterLoan), 0)
    }

    func testBorrowOnCreditCardFailsWhenRuleIsDisabled() {
        let player = Player(name: "Ana", balance: 1000)
        let state = GameState(players: [player], properties: [])

        XCTAssertThrowsError(try GameRules.borrowOnCreditCard(in: state, playerID: player.id, amount: 100, installments: 1)) { error in
            XCTAssertEqual(error as? GameRuleError, .creditCardsDisabled)
        }
    }

    func testPayCreditCardReducesLoanDebtAndCash() throws {
        let loan = CreditCardLoan(remainingDebt: 550, installmentsRemaining: 2, postponementsRemaining: 3)
        let player = Player(name: "Ana", balance: 300, creditCardLoans: [loan])
        let state = GameState(players: [player], properties: [])

        let result = try GameRules.payCreditCard(in: state, playerID: player.id, loanID: loan.id, amount: 200)

        XCTAssertEqual(result.players[0].balance, 100)
        XCTAssertEqual(result.players[0].creditCardLoans[0].remainingDebt, 350)
        XCTAssertEqual(GameRules.creditCardInstallmentDue(for: result.players[0].creditCardLoans[0]), 175)
    }

    func testPayCreditCardInFullRemovesTheLoan() throws {
        let loan = CreditCardLoan(remainingDebt: 100, installmentsRemaining: 2, postponementsRemaining: 3)
        let player = Player(name: "Ana", balance: 300, creditCardLoans: [loan])
        let state = GameState(players: [player], properties: [])

        let result = try GameRules.payCreditCard(in: state, playerID: player.id, loanID: loan.id, amount: 100)

        XCTAssertTrue(result.players[0].creditCardLoans.isEmpty)
    }

    func testPayCreditCardFailsWhenPayingMoreThanTheLoan() {
        let loan = CreditCardLoan(remainingDebt: 100, installmentsRemaining: 1, postponementsRemaining: 4)
        let player = Player(name: "Ana", balance: 300, creditCardLoans: [loan])
        let state = GameState(players: [player], properties: [])

        XCTAssertThrowsError(try GameRules.payCreditCard(in: state, playerID: player.id, loanID: loan.id, amount: 101)) { error in
            XCTAssertEqual(error as? GameRuleError, .invalidAmount(101))
        }
    }

    func testCollectSalaryChargesOneInstallmentPerLoan() throws {
        let fourInstallments = CreditCardLoan(remainingDebt: 1100, installmentsRemaining: 4, postponementsRemaining: 1)
        let threeInstallments = CreditCardLoan(remainingDebt: 1000, installmentsRemaining: 3, postponementsRemaining: 2)
        let player = Player(name: "Ana", balance: 1000, creditCardLoans: [fourInstallments, threeInstallments])
        let state = GameState(players: [player], properties: [])

        let result = try GameRules.collectSalary(in: state, playerID: player.id, amount: 200)

        XCTAssertEqual(result.players[0].balance, 1200 - 275 - 334)
        XCTAssertEqual(result.players[0].creditCardLoans[0].remainingDebt, 825)
        XCTAssertEqual(result.players[0].creditCardLoans[0].installmentsRemaining, 3)
        XCTAssertEqual(result.players[0].creditCardLoans[1].remainingDebt, 666)
        XCTAssertEqual(result.players[0].creditCardLoans[1].installmentsRemaining, 2)
    }

    func testCollectSalaryPaysOffLoanOverItsInstallments() throws {
        let player = Player(name: "Ana", balance: 1000)
        var state = GameState(players: [player], properties: [], activeHouseRules: [.creditCards])
        state = try GameRules.borrowOnCreditCard(in: state, playerID: player.id, amount: 300, installments: 3)

        for _ in 0..<3 {
            state = try GameRules.collectSalary(in: state, playerID: player.id, amount: 0)
        }

        XCTAssertTrue(state.players[0].creditCardLoans.isEmpty)
        XCTAssertEqual(state.players[0].balance, 1300 - 330)
    }

    func testCollectSalaryPostponesInstallmentWithoutCharging() throws {
        let loan = CreditCardLoan(remainingDebt: 1100, installmentsRemaining: 4, postponementsRemaining: 1)
        let player = Player(name: "Ana", balance: 100, creditCardLoans: [loan])
        let state = GameState(players: [player], properties: [])

        let result = try GameRules.collectSalary(in: state, playerID: player.id, amount: 200, postponedLoanIDs: [loan.id])

        XCTAssertEqual(result.players[0].balance, 300)
        XCTAssertEqual(result.players[0].creditCardLoans[0].remainingDebt, 1100)
        XCTAssertEqual(result.players[0].creditCardLoans[0].installmentsRemaining, 4)
        XCTAssertEqual(result.players[0].creditCardLoans[0].postponementsRemaining, 0)
    }

    func testCollectSalaryFailsWhenNoPostponementsAreLeft() {
        let loan = CreditCardLoan(remainingDebt: 1100, installmentsRemaining: 5, postponementsRemaining: 0)
        let player = Player(name: "Ana", balance: 100, creditCardLoans: [loan])
        let state = GameState(players: [player], properties: [])

        XCTAssertThrowsError(try GameRules.collectSalary(in: state, playerID: player.id, amount: 200, postponedLoanIDs: [loan.id])) { error in
            XCTAssertEqual(error as? GameRuleError, .noPostponementsLeft(loan.id))
        }
    }

    func testCollectSalaryChargesOnlyAvailableCashAndKeepsLastInstallmentOpen() throws {
        let loan = CreditCardLoan(remainingDebt: 500, installmentsRemaining: 1, postponementsRemaining: 0)
        let player = Player(name: "Ana", balance: 0, creditCardLoans: [loan])
        let state = GameState(players: [player], properties: [])

        let result = try GameRules.collectSalary(in: state, playerID: player.id, amount: 200)

        XCTAssertEqual(result.players[0].balance, 0)
        XCTAssertEqual(result.players[0].creditCardLoans[0].remainingDebt, 300)
        XCTAssertEqual(result.players[0].creditCardLoans[0].installmentsRemaining, 1)
        XCTAssertEqual(GameRules.creditCardInstallmentDue(for: result.players[0].creditCardLoans[0]), 300)
    }

    func testDeclareBankruptcyClearsCreditCardLoans() throws {
        let loan = CreditCardLoan(remainingDebt: 500, installmentsRemaining: 2, postponementsRemaining: 3)
        let player = Player(name: "Ana", balance: 10, creditCardLoans: [loan])
        let state = GameState(players: [player], properties: [])

        let result = try GameRules.declareBankruptcy(in: state, playerID: player.id, creditor: .bank)

        XCTAssertTrue(result.players[0].creditCardLoans.isEmpty)
    }

    func testEndTurnPassesToNextPlayerAndStartsNewRoundAfterLast() throws {
        let ana = Player(name: "Ana", balance: 100)
        let luis = Player(name: "Luis", balance: 100)
        let state = GameState(players: [ana, luis], properties: [], currentPlayerID: ana.id)

        let afterAna = try GameRules.endTurn(in: state, playerID: ana.id)
        let afterLuis = try GameRules.endTurn(in: afterAna, playerID: luis.id)

        XCTAssertEqual(afterAna.currentPlayerID, luis.id)
        XCTAssertEqual(afterAna.round, 1)
        XCTAssertEqual(afterLuis.currentPlayerID, ana.id)
        XCTAssertEqual(afterLuis.round, 2)
    }

    func testEndTurnSkipsBankruptPlayers() throws {
        let ana = Player(name: "Ana", balance: 100)
        let bankrupt = Player(name: "Luis", balance: 0, status: .bankrupt)
        let eva = Player(name: "Eva", balance: 100)
        let state = GameState(players: [ana, bankrupt, eva], properties: [], currentPlayerID: ana.id)

        let result = try GameRules.endTurn(in: state, playerID: ana.id)

        XCTAssertEqual(result.currentPlayerID, eva.id)
    }

    func testEndTurnFailsWhenItIsNotThePlayersTurn() {
        let ana = Player(name: "Ana", balance: 100)
        let luis = Player(name: "Luis", balance: 100)
        let state = GameState(players: [ana, luis], properties: [], currentPlayerID: ana.id)

        XCTAssertThrowsError(try GameRules.endTurn(in: state, playerID: luis.id)) { error in
            XCTAssertEqual(error as? GameRuleError, .notPlayersTurn(currentPlayerID: ana.id))
        }
    }

    func testDeclareBankruptcyOnYourTurnPassesTheTurn() throws {
        let ana = Player(name: "Ana", balance: 100)
        let luis = Player(name: "Luis", balance: 100)
        let state = GameState(players: [ana, luis], properties: [], currentPlayerID: ana.id)

        let result = try GameRules.declareBankruptcy(in: state, playerID: ana.id, creditor: .bank)

        XCTAssertEqual(result.currentPlayerID, luis.id)
    }

    func testLobbyBuildsGameStateInLobbyOrderStartingWithFirstPlayer() {
        let luis = LobbyPlayer(name: " Luis ", isHostControlled: false)
        let ana = LobbyPlayer(name: "Ana", isHostControlled: true)
        let lobby = Lobby(players: [luis, ana], creditCardsEnabled: false, proximityPaymentsEnabled: true)

        let state = lobby.makeGameState(initialBalance: 1500, properties: [])

        XCTAssertEqual(state.players.map(\.id), [luis.id, ana.id])
        XCTAssertEqual(state.players[0].name, "Luis")
        XCTAssertEqual(state.currentPlayerID, luis.id)
        XCTAssertEqual(state.round, 1)
        XCTAssertEqual(state.activeHouseRules, [])
        XCTAssertTrue(state.proximityPaymentsEnabled)
    }

    func testLobbyRequiresTwoToEightNamedPlayers() {
        XCTAssertFalse(Lobby(players: [LobbyPlayer(name: "Ana", isHostControlled: true)]).canStart)
        XCTAssertFalse(Lobby(players: [
            LobbyPlayer(name: "Ana", isHostControlled: true),
            LobbyPlayer(name: "  ", isHostControlled: false)
        ]).canStart)
        XCTAssertTrue(Lobby(players: [
            LobbyPlayer(name: "Ana", isHostControlled: true),
            LobbyPlayer(name: "Luis", isHostControlled: false)
        ]).canStart)
        XCTAssertFalse(Lobby(players: (1...9).map { LobbyPlayer(name: "J\($0)", isHostControlled: true) }).canStart)
    }

    func testExecuteTradeExchangesPropertyForMoney() throws {
        let property = Property(
            name: "Ana's Property",
            colorGroup: .brown,
            purchasePrice: 60,
            mortgageValue: 30,
            baseRent: 10,
            ownerID: nil
        )
        let firstPlayer = Player(name: "Ana", balance: 100, propertyIDs: [property.id])
        let secondPlayer = Player(name: "Luis", balance: 50)
        var ownedProperty = property
        ownedProperty.ownerID = firstPlayer.id
        let state = GameState(players: [firstPlayer, secondPlayer], properties: [ownedProperty])
        let offer = TradeOffer(
            fromPlayerID: firstPlayer.id,
            toPlayerID: secondPlayer.id,
            offeredPropertyIDs: [property.id],
            requestedMoney: 50
        )

        let result = try GameRules.executeTrade(in: state, offer: offer)

        XCTAssertEqual(result.players[0].balance, 150)
        XCTAssertEqual(result.players[1].balance, 0)
        XCTAssertEqual(result.players[0].propertyIDs, [])
        XCTAssertEqual(result.players[1].propertyIDs, [property.id])
        XCTAssertEqual(result.properties[0].ownerID, secondPlayer.id)
    }

    func testExecuteTradeExchangesPropertiesAndMoneyInBothDirections() throws {
        let firstProperty = Property(name: "Ana's Property", colorGroup: .brown, purchasePrice: 60, mortgageValue: 30, baseRent: 10)
        let secondProperty = Property(name: "Luis's Property", colorGroup: .lightBlue, purchasePrice: 100, mortgageValue: 50, baseRent: 12)
        let firstPlayer = Player(name: "Ana", balance: 100, propertyIDs: [firstProperty.id])
        let secondPlayer = Player(name: "Luis", balance: 100, propertyIDs: [secondProperty.id])
        var ownedFirstProperty = firstProperty
        ownedFirstProperty.ownerID = firstPlayer.id
        var ownedSecondProperty = secondProperty
        ownedSecondProperty.ownerID = secondPlayer.id
        let state = GameState(players: [firstPlayer, secondPlayer], properties: [ownedFirstProperty, ownedSecondProperty])
        let offer = TradeOffer(
            fromPlayerID: firstPlayer.id,
            toPlayerID: secondPlayer.id,
            offeredPropertyIDs: [firstProperty.id],
            offeredMoney: 10,
            requestedPropertyIDs: [secondProperty.id],
            requestedMoney: 20
        )

        let result = try GameRules.executeTrade(in: state, offer: offer)

        XCTAssertEqual(result.players[0].balance, 110)
        XCTAssertEqual(result.players[1].balance, 90)
        XCTAssertEqual(result.properties[0].ownerID, secondPlayer.id)
        XCTAssertEqual(result.properties[1].ownerID, firstPlayer.id)
        XCTAssertEqual(result.players[0].propertyIDs, [secondProperty.id])
        XCTAssertEqual(result.players[1].propertyIDs, [firstProperty.id])
    }

    func testExecuteTradeFailsAtomicallyWhenOfferedPropertyIsNotOwned() {
        let firstPlayer = Player(name: "Ana", balance: 100)
        let secondPlayer = Player(name: "Luis", balance: 100)
        let property = Property(name: "Luis's Property", colorGroup: .brown, purchasePrice: 60, mortgageValue: 30, baseRent: 10, ownerID: secondPlayer.id)
        let state = GameState(players: [firstPlayer, secondPlayer], properties: [property])
        let offer = TradeOffer(
            fromPlayerID: firstPlayer.id,
            toPlayerID: secondPlayer.id,
            offeredPropertyIDs: [property.id],
            requestedMoney: 50
        )

        XCTAssertThrowsError(try GameRules.executeTrade(in: state, offer: offer)) { error in
            XCTAssertEqual(
                error as? GameRuleError,
                .propertyNotOwnedByPlayer(propertyID: property.id, playerID: firstPlayer.id)
            )
        }
        XCTAssertEqual(state.players[0].balance, 100)
        XCTAssertEqual(state.players[1].balance, 100)
        XCTAssertEqual(state.properties[0].ownerID, secondPlayer.id)
    }

    func testExecuteTradeFailsWhenOfferedMoneyIsInsufficient() {
        let property = Property(name: "Ana's Property", colorGroup: .brown, purchasePrice: 60, mortgageValue: 30, baseRent: 10, ownerID: nil)
        let firstPlayer = Player(name: "Ana", balance: 9, propertyIDs: [property.id])
        let secondPlayer = Player(name: "Luis", balance: 100)
        var ownedProperty = property
        ownedProperty.ownerID = firstPlayer.id
        let state = GameState(players: [firstPlayer, secondPlayer], properties: [ownedProperty])
        let offer = TradeOffer(
            fromPlayerID: firstPlayer.id,
            toPlayerID: secondPlayer.id,
            offeredPropertyIDs: [property.id],
            offeredMoney: 10
        )

        XCTAssertThrowsError(try GameRules.executeTrade(in: state, offer: offer)) { error in
            XCTAssertEqual(
                error as? GameRuleError,
                .insufficientFunds(playerID: firstPlayer.id, required: 10, available: 9)
            )
        }
    }

    func testExecuteTradeFailsWhenParticipantIsBankrupt() {
        let firstPlayer = Player(name: "Ana", balance: 100)
        let secondPlayer = Player(name: "Luis", balance: 100, status: .bankrupt)
        let state = GameState(players: [firstPlayer, secondPlayer], properties: [])
        let offer = TradeOffer(fromPlayerID: firstPlayer.id, toPlayerID: secondPlayer.id)

        XCTAssertThrowsError(try GameRules.executeTrade(in: state, offer: offer)) { error in
            XCTAssertEqual(error as? GameRuleError, .playerIsBankrupt(secondPlayer.id))
        }
    }

    func testExecuteTradePreservesConstructionAndMortgageState() throws {
        let builtProperty = Property(
            name: "Built Property",
            colorGroup: .brown,
            purchasePrice: 60,
            mortgageValue: 30,
            baseRent: 10,
            constructionLevel: 2,
            ownerID: nil
        )
        let mortgagedProperty = Property(
            name: "Mortgaged Property",
            colorGroup: .lightBlue,
            purchasePrice: 100,
            mortgageValue: 50,
            baseRent: 12,
            ownerID: nil,
            isMortgaged: true
        )
        let firstPlayer = Player(name: "Ana", balance: 100, propertyIDs: [builtProperty.id])
        let secondPlayer = Player(name: "Luis", balance: 100, propertyIDs: [mortgagedProperty.id])
        var ownedBuiltProperty = builtProperty
        ownedBuiltProperty.ownerID = firstPlayer.id
        var ownedMortgagedProperty = mortgagedProperty
        ownedMortgagedProperty.ownerID = secondPlayer.id
        let state = GameState(players: [firstPlayer, secondPlayer], properties: [ownedBuiltProperty, ownedMortgagedProperty])
        let offer = TradeOffer(
            fromPlayerID: firstPlayer.id,
            toPlayerID: secondPlayer.id,
            offeredPropertyIDs: [builtProperty.id],
            requestedPropertyIDs: [mortgagedProperty.id]
        )

        let result = try GameRules.executeTrade(in: state, offer: offer)

        XCTAssertEqual(result.properties[0].constructionLevel, 2)
        XCTAssertFalse(result.properties[0].isMortgaged)
        XCTAssertEqual(result.properties[1].constructionLevel, 0)
        XCTAssertTrue(result.properties[1].isMortgaged)
    }
}

final class NetworkingTests: XCTestCase {
    func testGameIntentRoundTripsThroughCodable() throws {
        let playerID = UUID()
        let propertyID = UUID()
        let otherPlayerID = UUID()
        let offer = TradeOffer(
            fromPlayerID: playerID,
            toPlayerID: otherPlayerID,
            offeredPropertyIDs: [propertyID],
            requestedMoney: 40
        )
        let intents: [GameIntent] = [
            .buyProperty(playerID: playerID, propertyID: propertyID),
            .executeTrade(offer: offer),
            .resolveAuction(
                propertyID: propertyID,
                bids: [AuctionBid(playerID: playerID, amount: 100)]
            ),
            .transferMoney(payerID: playerID, recipientID: otherPlayerID, amount: 50),
            .borrowOnCreditCard(playerID: playerID, amount: 300, installments: 4),
            .payCreditCard(playerID: playerID, loanID: UUID(), amount: 100),
            .collectSalary(playerID: playerID, amount: 200, postponedLoanIDs: [UUID()]),
            .endTurn(playerID: playerID),
            .skipTurn
        ]

        for intent in intents {
            let data = try JSONEncoder().encode(intent)
            let decoded = try JSONDecoder().decode(GameIntent.self, from: data)
            XCTAssertEqual(decoded, intent)
        }
    }

    func testNetworkMessageVariantsRoundTripThroughCodable() throws {
        let playerID = UUID()
        let propertyID = UUID()
        let state = GameState(
            players: [Player(
                id: playerID,
                name: "Ana",
                balance: 100,
                creditCardLoans: [CreditCardLoan(remainingDebt: 220, installmentsRemaining: 2, postponementsRemaining: 3)]
            )],
            properties: [Property(id: propertyID, name: "Property", colorGroup: .brown, purchasePrice: 60, mortgageValue: 30, baseRent: 10)],
            activeHouseRules: [.creditCards],
            proximityPaymentsEnabled: true
        )
        let messages: [NetworkMessage] = [
            .intent(
                playerID: playerID,
                intent: .buyProperty(playerID: playerID, propertyID: propertyID)
            ),
            .stateSnapshot(state),
            .intentRejected(.insufficientFunds(playerID: playerID, required: 200, available: 100)),
            .intentRejected(.transferParticipantsMustDiffer),
            .intentRejected(.creditLimitExceeded(requested: 600, available: 500)),
            .intentRejected(.invalidInstallments(6)),
            .intentRejected(.noPostponementsLeft(UUID())),
            .intentRejected(.notPlayersTurn(currentPlayerID: playerID)),
            .intentRejected(.onlyHostCanSkipTurn),
            .lobbySnapshot(Lobby(players: [LobbyPlayer(name: "Ana", isHostControlled: true)])),
            .joinLobby(LobbyPlayer(name: "Luis", isHostControlled: false)),
            .proximitySignal(ProximitySignal(
                sessionID: UUID(),
                kind: .invite,
                senderPlayerID: playerID,
                recipientPlayerID: UUID(),
                discoveryToken: Data([0x01, 0x02])
            ))
        ]

        for message in messages {
            let data = try JSONEncoder().encode(message)
            let decoded = try JSONDecoder().decode(NetworkMessage.self, from: data)
            XCTAssertEqual(decoded, message)
        }
    }

    func testGameSessionHostAppliesValidIntentAndBroadcastsSnapshot() throws {
        let player = Player(name: "Ana", balance: 200)
        let property = Property(name: "Property", colorGroup: .brown, purchasePrice: 100, mortgageValue: 50, baseRent: 10)
        let initialState = GameState(players: [player], properties: [property])
        let hostTransport = InMemoryGameTransport(peerID: PeerID("host"))
        let receivingTransport = InMemoryGameTransport(peerID: PeerID("client"))
        let host = GameSession(transport: hostTransport, role: .host, initialState: initialState)
        hostTransport.connect(to: receivingTransport)

        let intent = NetworkMessage.intent(
            playerID: player.id,
            intent: .buyProperty(playerID: player.id, propertyID: property.id)
        )
        hostTransport.inject(try JSONEncoder().encode(intent), from: receivingTransport.localPeerID)

        XCTAssertEqual(host.gameState?.players[0].balance, 100)
        XCTAssertEqual(host.gameState?.properties[0].ownerID, player.id)
        XCTAssertEqual(hostTransport.broadcastMessages.count, 1)
    }

    func testGameSessionHostRejectsInvalidIntentWithoutMutationOrBroadcast() throws {
        let owner = Player(name: "Luis", balance: 200)
        let requester = Player(name: "Ana", balance: 200)
        let property = Property(
            name: "Property",
            colorGroup: .brown,
            purchasePrice: 100,
            mortgageValue: 50,
            baseRent: 10,
            ownerID: owner.id
        )
        let initialState = GameState(players: [requester, owner], properties: [property])
        let hostTransport = InMemoryGameTransport(peerID: PeerID("host"))
        let clientTransport = InMemoryGameTransport(peerID: PeerID("client"))
        let host = GameSession(transport: hostTransport, role: .host, initialState: initialState)
        let client = GameSession(
            transport: clientTransport,
            role: .client,
            initialState: initialState,
            hostPeerID: hostTransport.localPeerID
        )
        var rejection: GameRuleError?
        client.onIntentRejected = { rejection = $0 }
        hostTransport.connect(to: clientTransport)

        try client.submit(
            intent: .buyProperty(playerID: requester.id, propertyID: property.id),
            playerID: requester.id
        )

        XCTAssertEqual(rejection, .propertyAlreadyOwned(propertyID: property.id, ownerID: owner.id))
        XCTAssertEqual(host.gameState, initialState)
        XCTAssertEqual(hostTransport.broadcastMessages.count, 0)
    }

    func testGameSessionClientReplacesLocalStateFromSnapshot() throws {
        let player = Player(name: "Ana", balance: 100)
        let property = Property(name: "Property", colorGroup: .brown, purchasePrice: 60, mortgageValue: 30, baseRent: 10)
        let initialState = GameState(players: [player], properties: [property])
        var updatedState = initialState
        updatedState.players[0].balance = 40
        updatedState.properties[0].ownerID = player.id
        let clientTransport = InMemoryGameTransport(peerID: PeerID("client"))
        let client = GameSession(
            transport: clientTransport,
            role: .client,
            initialState: initialState,
            hostPeerID: PeerID("host")
        )

        let snapshot = try JSONEncoder().encode(NetworkMessage.stateSnapshot(updatedState))
        clientTransport.inject(snapshot, from: PeerID("host"))

        XCTAssertEqual(client.gameState, updatedState)
    }

    func testGameSessionRoundTripUpdatesClientAfterIntent() throws {
        let player = Player(name: "Ana", balance: 200)
        let property = Property(name: "Property", colorGroup: .brown, purchasePrice: 100, mortgageValue: 50, baseRent: 10)
        let initialState = GameState(players: [player], properties: [property])
        let hostTransport = InMemoryGameTransport(peerID: PeerID("host"))
        let clientTransport = InMemoryGameTransport(peerID: PeerID("client"))
        let host = GameSession(transport: hostTransport, role: .host, initialState: initialState)
        let client = GameSession(
            transport: clientTransport,
            role: .client,
            initialState: initialState,
            hostPeerID: hostTransport.localPeerID
        )
        hostTransport.connect(to: clientTransport)

        try client.submit(
            intent: .buyProperty(playerID: player.id, propertyID: property.id),
            playerID: player.id
        )

        XCTAssertEqual(host.gameState?.players[0].balance, 100)
        XCTAssertEqual(client.gameState?.players[0].balance, 100)
        XCTAssertEqual(client.gameState?.properties[0].ownerID, player.id)
    }
}

extension NetworkingTests {
    func testGameSessionHostAppliesTransferAsTheSubmittingPlayer() throws {
        let payer = Player(name: "Ana", balance: 200)
        let recipient = Player(name: "Luis", balance: 100)
        let initialState = GameState(players: [payer, recipient], properties: [])
        let hostTransport = InMemoryGameTransport(peerID: PeerID("host"))
        let clientTransport = InMemoryGameTransport(peerID: PeerID("client"))
        let host = GameSession(transport: hostTransport, role: .host, initialState: initialState)
        let client = GameSession(
            transport: clientTransport,
            role: .client,
            initialState: initialState,
            hostPeerID: hostTransport.localPeerID
        )
        hostTransport.connect(to: clientTransport)

        try client.submit(
            intent: .transferMoney(payerID: recipient.id, recipientID: recipient.id, amount: 75),
            playerID: payer.id
        )

        XCTAssertEqual(host.gameState?.players[0].balance, 125)
        XCTAssertEqual(host.gameState?.players[1].balance, 175)
    }

    func testGameSessionHostRelaysProximitySignalBetweenClients() throws {
        let initialState = GameState(players: [], properties: [], proximityPaymentsEnabled: true)
        let hostTransport = InMemoryGameTransport(peerID: PeerID("host"))
        let payerTransport = InMemoryGameTransport(peerID: PeerID("payer"))
        let receiverTransport = InMemoryGameTransport(peerID: PeerID("receiver"))
        let host = GameSession(transport: hostTransport, role: .host, initialState: initialState)
        let payer = GameSession(transport: payerTransport, role: .client, hostPeerID: hostTransport.localPeerID)
        let receiver = GameSession(transport: receiverTransport, role: .client, hostPeerID: hostTransport.localPeerID)
        hostTransport.connect(to: payerTransport)
        hostTransport.connect(to: receiverTransport)
        var hostSignals: [ProximitySignal] = []
        var receiverSignals: [ProximitySignal] = []
        host.onProximitySignal = { hostSignals.append($0) }
        receiver.onProximitySignal = { receiverSignals.append($0) }
        let signal = ProximitySignal(
            sessionID: UUID(),
            kind: .invite,
            senderPlayerID: UUID(),
            recipientPlayerID: UUID(),
            discoveryToken: Data([0xAB])
        )

        try payer.sendProximitySignal(signal)

        XCTAssertEqual(hostSignals, [signal])
        XCTAssertEqual(receiverSignals, [signal])
        XCTAssertEqual(host.gameState, initialState)
    }

    func testGameSessionHostBroadcastsItsOwnProximitySignal() throws {
        let initialState = GameState(players: [], properties: [], proximityPaymentsEnabled: true)
        let hostTransport = InMemoryGameTransport(peerID: PeerID("host"))
        let clientTransport = InMemoryGameTransport(peerID: PeerID("client"))
        let host = GameSession(transport: hostTransport, role: .host, initialState: initialState)
        let client = GameSession(transport: clientTransport, role: .client, hostPeerID: hostTransport.localPeerID)
        hostTransport.connect(to: clientTransport)
        var clientSignals: [ProximitySignal] = []
        client.onProximitySignal = { clientSignals.append($0) }
        let signal = ProximitySignal(
            sessionID: UUID(),
            kind: .cancel,
            senderPlayerID: UUID(),
            recipientPlayerID: UUID()
        )

        try host.sendProximitySignal(signal)

        XCTAssertEqual(clientSignals, [signal])
    }

    func testGameSessionRejectsTurnActionFromPlayerWhoseTurnItIsNot() throws {
        let ana = Player(name: "Ana", balance: 200)
        let luis = Player(name: "Luis", balance: 200)
        let initialState = GameState(players: [ana, luis], properties: [], currentPlayerID: ana.id)
        let hostTransport = InMemoryGameTransport(peerID: PeerID("host"))
        let clientTransport = InMemoryGameTransport(peerID: PeerID("client"))
        let host = GameSession(transport: hostTransport, role: .host, initialState: initialState)
        let client = GameSession(transport: clientTransport, role: .client, hostPeerID: hostTransport.localPeerID)
        var rejection: GameRuleError?
        client.onIntentRejected = { rejection = $0 }
        hostTransport.connect(to: clientTransport)

        try client.submit(intent: .collectSalary(playerID: luis.id, amount: 200), playerID: luis.id)

        XCTAssertEqual(rejection, .notPlayersTurn(currentPlayerID: ana.id))
        XCTAssertEqual(host.gameState?.players[1].balance, 200)
    }

    func testGameSessionAllowsOutOfTurnTransfer() throws {
        let ana = Player(name: "Ana", balance: 200)
        let luis = Player(name: "Luis", balance: 200)
        let initialState = GameState(players: [ana, luis], properties: [], currentPlayerID: ana.id)
        let hostTransport = InMemoryGameTransport(peerID: PeerID("host"))
        let clientTransport = InMemoryGameTransport(peerID: PeerID("client"))
        let host = GameSession(transport: hostTransport, role: .host, initialState: initialState)
        let client = GameSession(transport: clientTransport, role: .client, hostPeerID: hostTransport.localPeerID)
        hostTransport.connect(to: clientTransport)

        try client.submit(intent: .transferMoney(payerID: luis.id, recipientID: ana.id, amount: 50), playerID: luis.id)

        XCTAssertEqual(host.gameState?.players[0].balance, 250)
    }

    func testOnlyHostCanSkipAnotherPlayersTurn() throws {
        let ana = Player(name: "Ana", balance: 200)
        let luis = Player(name: "Luis", balance: 200)
        let initialState = GameState(players: [ana, luis], properties: [], currentPlayerID: ana.id)
        let hostTransport = InMemoryGameTransport(peerID: PeerID("host"))
        let clientTransport = InMemoryGameTransport(peerID: PeerID("client"))
        let host = GameSession(transport: hostTransport, role: .host, initialState: initialState)
        let client = GameSession(transport: clientTransport, role: .client, hostPeerID: hostTransport.localPeerID)
        var rejection: GameRuleError?
        client.onIntentRejected = { rejection = $0 }
        hostTransport.connect(to: clientTransport)

        try client.submit(intent: .skipTurn, playerID: luis.id)
        XCTAssertEqual(rejection, .onlyHostCanSkipTurn)
        XCTAssertEqual(host.gameState?.currentPlayerID, ana.id)

        try host.submitLocal(intent: .skipTurn, playerID: luis.id)
        XCTAssertEqual(host.gameState?.currentPlayerID, luis.id)
    }

    func testClientJoinsHostLobbyWithItsNameAndLeavesOnDisconnect() throws {
        let hostPlayer = LobbyPlayer(name: "Brian", isHostControlled: true)
        let joiningPlayer = LobbyPlayer(name: "Luis", isHostControlled: false)
        let hostTransport = InMemoryGameTransport(peerID: PeerID("host"))
        let clientTransport = InMemoryGameTransport(peerID: PeerID("client"))
        let host = GameSession(transport: hostTransport, role: .host, lobby: Lobby(players: [hostPlayer]))
        let client = GameSession(transport: clientTransport, role: .client, lobbyPlayer: joiningPlayer)

        hostTransport.connect(to: clientTransport)

        XCTAssertEqual(host.lobby?.players, [hostPlayer, joiningPlayer])
        XCTAssertEqual(client.lobby?.players, [hostPlayer, joiningPlayer])

        hostTransport.disconnect(from: clientTransport)

        XCTAssertEqual(host.lobby?.players, [hostPlayer])
    }

    func testHostStartGameSendsStateToLobbyClients() throws {
        let hostPlayer = LobbyPlayer(name: "Brian", isHostControlled: true)
        let joiningPlayer = LobbyPlayer(name: "Luis", isHostControlled: false)
        let hostTransport = InMemoryGameTransport(peerID: PeerID("host"))
        let clientTransport = InMemoryGameTransport(peerID: PeerID("client"))
        let host = GameSession(transport: hostTransport, role: .host, lobby: Lobby(players: [hostPlayer]))
        let client = GameSession(transport: clientTransport, role: .client, lobbyPlayer: joiningPlayer)
        hostTransport.connect(to: clientTransport)
        let state = try XCTUnwrap(host.lobby).makeGameState(initialBalance: 1500, properties: [])

        try host.startGame(with: state)

        XCTAssertEqual(client.gameState, state)
        XCTAssertNil(client.lobby)
        XCTAssertNil(host.lobby)
        XCTAssertThrowsError(try host.updateLobby(Lobby())) { error in
            XCTAssertEqual(error as? GameSessionError, .gameAlreadyStarted)
        }
    }

    func testClientIsNotifiedWhenHostDisconnectsAndReconnects() throws {
        let hostTransport = InMemoryGameTransport(peerID: PeerID("host"))
        let clientTransport = InMemoryGameTransport(peerID: PeerID("client"))
        let state = GameState(players: [Player(name: "Ana", balance: 100)], properties: [])
        let host = GameSession(transport: hostTransport, role: .host, initialState: state)
        let client = GameSession(transport: clientTransport, role: .client)
        var connectionChanges: [Bool] = []
        client.onHostConnectionChanged = { connectionChanges.append($0) }

        hostTransport.connect(to: clientTransport)
        hostTransport.disconnect(from: clientTransport)
        let restartedHostTransport = InMemoryGameTransport(peerID: PeerID("host-restarted"))
        let restartedHost = GameSession(transport: restartedHostTransport, role: .host, initialState: state)
        restartedHostTransport.connect(to: clientTransport)

        XCTAssertEqual(connectionChanges, [true, false, true])
        XCTAssertEqual(client.gameState, state)
        withExtendedLifetime((host, restartedHost)) {}
    }

    func testGameStateDisablesProximityPaymentsByDefault() {
        XCTAssertFalse(GameState(players: [], properties: []).proximityPaymentsEnabled)
    }
}

final class GameStoreTests: XCTestCase {
    private var fileURL: URL!

    override func setUp() {
        super.setUp()
        fileURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
            .appending(path: "saved-game.json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
        super.tearDown()
    }

    func testSavedGameRoundTripsThroughDisk() throws {
        let store = GameStore(fileURL: fileURL)
        let ana = Player(
            name: "Ana",
            balance: 900,
            creditCardLoans: [CreditCardLoan(remainingDebt: 330, installmentsRemaining: 3, postponementsRemaining: 2)]
        )
        let luis = Player(name: "Luis", balance: 1500)
        let state = GameState(
            players: [ana, luis],
            properties: [Property(name: "Property", colorGroup: .brown, purchasePrice: 60, mortgageValue: 30, baseRent: 2, ownerID: ana.id)],
            currentPlayerID: luis.id,
            round: 4,
            activeHouseRules: [.creditCards],
            proximityPaymentsEnabled: true
        )
        let savedGame = SavedGame(
            state: state,
            ownPlayerID: ana.id,
            hostControlledPlayerIDs: [ana.id, luis.id],
            savedAt: Date(timeIntervalSince1970: 1_000_000)
        )

        try store.save(savedGame)

        XCTAssertEqual(store.load(), savedGame)
    }

    func testLoadReturnsNilWithoutSaveOrWithUnreadableFile() throws {
        let store = GameStore(fileURL: fileURL)
        XCTAssertNil(store.load())

        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not a game".utf8).write(to: fileURL)

        XCTAssertNil(store.load())
    }

    func testDeleteRemovesSavedGame() throws {
        let store = GameStore(fileURL: fileURL)
        let player = Player(name: "Ana", balance: 100)
        try store.save(SavedGame(
            state: GameState(players: [player], properties: []),
            ownPlayerID: player.id,
            hostControlledPlayerIDs: [player.id],
            savedAt: Date()
        ))

        store.delete()

        XCTAssertNil(store.load())
    }
}

private final class InMemoryGameTransport: GameTransport {
    let localPeerID: PeerID

    var onDataReceived: ((Data, PeerID) -> Void)?
    var onPeerConnected: ((PeerID) -> Void)?
    var onPeerDisconnected: ((PeerID) -> Void)?

    private var peers: [PeerID: InMemoryGameTransport] = [:]
    private(set) var sentMessages: [(data: Data, peerID: PeerID)] = []
    private(set) var broadcastMessages: [Data] = []

    init(peerID: PeerID) {
        self.localPeerID = peerID
    }

    func connect(to other: InMemoryGameTransport) {
        peers[other.localPeerID] = other
        other.peers[localPeerID] = self
        onPeerConnected?(other.localPeerID)
        other.onPeerConnected?(localPeerID)
    }

    func send(data: Data, to peer: PeerID) throws {
        guard let destination = peers[peer] else {
            throw GameTransportError.peerNotConnected(peer)
        }

        sentMessages.append((data: data, peerID: peer))
        destination.onDataReceived?(data, localPeerID)
    }

    func broadcast(data: Data) throws {
        broadcastMessages.append(data)
        for destination in peers.values {
            destination.onDataReceived?(data, localPeerID)
        }
    }

    func disconnect(from other: InMemoryGameTransport) {
        peers[other.localPeerID] = nil
        other.peers[localPeerID] = nil
        onPeerDisconnected?(other.localPeerID)
        other.onPeerDisconnected?(localPeerID)
    }

    func startHosting() {
    }

    func startBrowsing() {
    }

    func stop() {
    }

    func inject(_ data: Data, from peerID: PeerID) {
        onDataReceived?(data, peerID)
    }
}
