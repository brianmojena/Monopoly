import XCTest
@testable import Monopoly

/// GAME_RULES section 4.3: any shareholder levels up, covering whoever can't pay.
final class ShareCoverageTests: XCTestCase {
    private var ana = Player(name: "Ana", balance: 1_000)
    private var luis = Player(name: "Luis", balance: 0)

    /// A $200 street at level 3 held 30% Ana / 70% Luis, with its group partner managed
    /// by Luis too so the group stays his monopoly.
    private func makeState(anaBalance: Int = 1_000, luisBalance: Int = 0) -> GameState {
        ana.balance = anaBalance
        luis.balance = luisBalance
        let street = Property(
            name: "Street",
            colorGroup: .brown,
            purchasePrice: 200,
            mortgageValue: 100,
            baseRent: 20,
            constructionLevel: 3,
            ownership: [PropertyShare(playerID: luis.id, shares: 7), PropertyShare(playerID: ana.id, shares: 3)]
        )
        let partner = Property(
            name: "Partner",
            colorGroup: .brown,
            purchasePrice: 200,
            mortgageValue: 100,
            baseRent: 20,
            constructionLevel: 3,
            ownerID: luis.id
        )
        return GameState(players: [ana, luis], properties: [street, partner])
    }

    func testMinorityShareholderCoversThePartOfWhoeverCannotPay() throws {
        let state = makeState()
        let streetID = state.properties[0].id

        let result = try GameRules.levelUp(in: state, propertyID: streetID, playerID: ana.id)

        XCTAssertEqual(result.properties[0].constructionLevel, 4)
        XCTAssertEqual(result.players[0].balance, 1_000 - 300)
        XCTAssertEqual(result.players[1].balance, 0)
        // $210 covered at $95 a share (200 + 750 of levels, /10) is 2 shares.
        XCTAssertEqual(result.properties[0].shares(of: ana.id), 5)
        XCTAssertEqual(result.properties[0].shares(of: luis.id), 5)
        XCTAssertEqual(result.shareCoverages.count, 1)
        XCTAssertEqual(result.shareCoverages[0].payerID, ana.id)
        XCTAssertEqual(result.shareCoverages[0].coveredPlayerID, luis.id)
        XCTAssertEqual(result.shareCoverages[0].amount, 210)
        XCTAssertEqual(result.shareCoverages[0].shares, 2)
    }

    func testShareholdersWhoCanPayPayTheirOwnPart() throws {
        let state = makeState(luisBalance: 500)

        let result = try GameRules.levelUp(in: state, propertyID: state.properties[0].id, playerID: ana.id)

        XCTAssertEqual(result.players[0].balance, 1_000 - 90)
        XCTAssertEqual(result.players[1].balance, 500 - 210)
        XCTAssertEqual(result.properties[0].shares(of: ana.id), 3)
        XCTAssertTrue(result.shareCoverages.isEmpty)
    }

    func testLevelUpFailsWhenThePayerCannotCoverEveryPart() {
        let state = makeState(anaBalance: 299)

        XCTAssertThrowsError(try GameRules.levelUp(in: state, propertyID: state.properties[0].id, playerID: ana.id)) { error in
            XCTAssertEqual(error as? GameRuleError, .insufficientFunds(playerID: ana.id, required: 300, available: 299))
        }
    }

    func testOnlyShareholdersCanLevelUp() {
        var state = makeState()
        let stranger = Player(name: "Eva", balance: 5_000)
        state.players.append(stranger)

        XCTAssertThrowsError(try GameRules.levelUp(in: state, propertyID: state.properties[0].id, playerID: stranger.id)) { error in
            XCTAssertEqual(error as? GameRuleError, .propertyNotOwnedByPlayer(propertyID: state.properties[0].id, playerID: stranger.id))
        }
    }

    func testCoveredPlayerBuysTheSharesBack() throws {
        let base = makeState()
        var state = try GameRules.levelUp(in: base, propertyID: base.properties[0].id, playerID: ana.id)
        state.players[1].balance = 300
        let coverageID = state.shareCoverages[0].id

        let result = try GameRules.buyBackShares(in: state, coverageID: coverageID, playerID: luis.id)

        XCTAssertEqual(result.players[1].balance, 90)
        XCTAssertEqual(result.players[0].balance, 700 + 210)
        XCTAssertEqual(result.properties[0].shares(of: ana.id), 3)
        XCTAssertEqual(result.properties[0].shares(of: luis.id), 7)
        XCTAssertTrue(result.shareCoverages.isEmpty)
    }

    func testBuyBackNeedsTheMoneyAndThePayersShares() throws {
        let base = makeState()
        var state = try GameRules.levelUp(in: base, propertyID: base.properties[0].id, playerID: ana.id)
        let coverageID = state.shareCoverages[0].id

        XCTAssertThrowsError(try GameRules.buyBackShares(in: state, coverageID: coverageID, playerID: luis.id)) { error in
            XCTAssertEqual(error as? GameRuleError, .insufficientFunds(playerID: luis.id, required: 210, available: 0))
        }
        XCTAssertThrowsError(try GameRules.buyBackShares(in: state, coverageID: coverageID, playerID: ana.id)) { error in
            XCTAssertEqual(error as? GameRuleError, .shareCoverageNotFound(coverageID))
        }

        state.players[1].balance = 300
        state.properties[0].removeShares(4, from: ana.id)
        XCTAssertThrowsError(try GameRules.buyBackShares(in: state, coverageID: coverageID, playerID: luis.id)) { error in
            XCTAssertEqual(error as? GameRuleError, .notEnoughShares(propertyID: state.properties[0].id, playerID: ana.id))
        }
    }

    func testSmallPartsStillTakeOneShareButNeverMoreThanHeld() throws {
        // Luis holds a single 10% share; his part of level 1 on a $60 street is $3.
        let eva = Player(name: "Eva", balance: 1_000)
        let broke = Player(name: "Luis", balance: 0)
        let street = Property(
            name: "Street", colorGroup: .brown, purchasePrice: 60, mortgageValue: 30, baseRent: 2,
            ownership: [PropertyShare(playerID: eva.id, shares: 9), PropertyShare(playerID: broke.id, shares: 1)]
        )
        let partner = Property(name: "Partner", colorGroup: .brown, purchasePrice: 60, mortgageValue: 30, baseRent: 4, ownerID: eva.id)
        let state = GameState(players: [eva, broke], properties: [street, partner])

        let result = try GameRules.levelUp(in: state, propertyID: street.id, playerID: eva.id)

        XCTAssertEqual(result.properties[0].shares(of: eva.id), 10)
        XCTAssertEqual(result.properties[0].shares(of: broke.id), 0)
        XCTAssertFalse(result.players[1].propertyIDs.contains(street.id))
        XCTAssertEqual(result.shareCoverages.first?.shares, 1)
    }

    func testBankruptcyDropsTheCoverage() throws {
        let base = makeState()
        let state = try GameRules.levelUp(in: base, propertyID: base.properties[0].id, playerID: ana.id)

        let result = try GameRules.declareBankruptcy(in: state, playerID: luis.id, creditor: .bank)

        XCTAssertTrue(result.shareCoverages.isEmpty)
    }

    func testCoveragesSurviveSavingAndOlderSavesLoadWithoutThem() throws {
        let base = makeState()
        let state = try GameRules.levelUp(in: base, propertyID: base.properties[0].id, playerID: ana.id)
        let data = try JSONEncoder().encode(state)
        XCTAssertEqual(try JSONDecoder().decode(GameState.self, from: data), state)

        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "shareCoverages")
        let legacy = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(legacy.shareCoverages.isEmpty)
    }

    func testBuyBackIntentRoundTrips() throws {
        let intent = GameIntent.buyBackShares(coverageID: UUID(), playerID: UUID())
        let decoded = try JSONDecoder().decode(GameIntent.self, from: JSONEncoder().encode(intent))
        XCTAssertEqual(decoded, intent)
    }
}
