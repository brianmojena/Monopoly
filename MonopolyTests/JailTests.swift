import XCTest
@testable import Monopoly

/// GAME_RULES section 5: jail turns shown to everyone, and the two ways out.
final class JailTests: XCTestCase {
    private let ana = Player(name: "Ana", balance: 500)
    private let luis = Player(name: "Luis", balance: 500)

    private func makeState(rules: Set<HouseRule> = []) -> GameState {
        GameState(players: [ana, luis], properties: [], currentPlayerID: ana.id, activeHouseRules: rules)
    }

    private func jailTurn(_ player: Player, in state: GameState) -> Int? {
        state.players.first(where: { $0.id == player.id })?.jailTurn
    }

    func testGoingToJailStartsAtTurnZeroAndOnlyOnce() throws {
        let state = try GameRules.goToJail(in: makeState(), playerID: ana.id)

        XCTAssertEqual(jailTurn(ana, in: state), 0)
        XCTAssertThrowsError(try GameRules.goToJail(in: state, playerID: ana.id)) { error in
            XCTAssertEqual(error as? GameRuleError, .alreadyInJail(ana.id))
        }
    }

    func testEachTurnStartedInJailCountsOneMore() throws {
        var state = try GameRules.goToJail(in: makeState(), playerID: ana.id)

        state = GameRules.advanceTurn(in: state)
        XCTAssertEqual(jailTurn(ana, in: state), 0)
        XCTAssertNil(jailTurn(luis, in: state))

        state = GameRules.advanceTurn(in: state)
        XCTAssertEqual(jailTurn(ana, in: state), 1)

        state = GameRules.advanceTurn(in: GameRules.advanceTurn(in: state))
        XCTAssertEqual(jailTurn(ana, in: state), 2)
    }

    func testAfterThreeTurnsThePlayerWalksOutForFree() throws {
        var state = try GameRules.goToJail(in: makeState(), playerID: ana.id)
        for _ in 1...GameRules.maximumJailTurns {
            state = GameRules.advanceTurn(in: GameRules.advanceTurn(in: state))
        }
        XCTAssertEqual(jailTurn(ana, in: state), GameRules.maximumJailTurns)

        state = GameRules.advanceTurn(in: GameRules.advanceTurn(in: state))

        XCTAssertNil(jailTurn(ana, in: state))
        XCTAssertEqual(state.currentPlayerID, ana.id)
        XCTAssertEqual(state.players[0].balance, 500)
    }

    func testDoublesGetOutForFree() throws {
        let jailed = try GameRules.goToJail(in: makeState(), playerID: ana.id)

        let state = try GameRules.leaveJail(in: jailed, playerID: ana.id, exit: .doubles)

        XCTAssertNil(jailTurn(ana, in: state))
        XCTAssertEqual(state.players[0].balance, 500)
    }

    func testTheFineGoesToTheFreeParkingPot() throws {
        let jailed = try GameRules.goToJail(in: makeState(rules: [.freeParkingJackpot]), playerID: ana.id)

        let state = try GameRules.leaveJail(in: jailed, playerID: ana.id, exit: .payFine)

        XCTAssertNil(jailTurn(ana, in: state))
        XCTAssertEqual(state.players[0].balance, 500 - GameRules.jailFine)
        XCTAssertEqual(state.freeParkingPot, GameRules.jailFine)
    }

    func testWithoutThePotTheFineLeavesTheGame() throws {
        let jailed = try GameRules.goToJail(in: makeState(), playerID: ana.id)

        let state = try GameRules.leaveJail(in: jailed, playerID: ana.id, exit: .payFine)

        XCTAssertEqual(state.players[0].balance, 400)
        XCTAssertEqual(state.freeParkingPot, 0)
    }

    func testTheFineNeedsTheMoneyAndLeavingNeedsToBeInJail() throws {
        var jailed = try GameRules.goToJail(in: makeState(), playerID: ana.id)
        jailed.players[0].balance = 50

        XCTAssertThrowsError(try GameRules.leaveJail(in: jailed, playerID: ana.id, exit: .payFine)) { error in
            XCTAssertEqual(error as? GameRuleError, .insufficientFunds(playerID: ana.id, required: 100, available: 50))
        }
        XCTAssertThrowsError(try GameRules.leaveJail(in: jailed, playerID: luis.id, exit: .doubles)) { error in
            XCTAssertEqual(error as? GameRuleError, .notInJail(luis.id))
        }
    }

    func testBankruptcyFreesThePlayer() throws {
        let jailed = try GameRules.goToJail(in: makeState(), playerID: ana.id)

        let state = try GameRules.declareBankruptcy(in: jailed, playerID: ana.id, creditor: .bank)

        XCTAssertNil(jailTurn(ana, in: state))
    }

    func testJailIntentsAreTurnActionsAndRoundTripThroughJSON() throws {
        let intents: [GameIntent] = [.goToJail(playerID: ana.id), .leaveJail(playerID: ana.id, exit: .payFine)]
        for intent in intents {
            XCTAssertTrue(intent.requiresTurn)
            XCTAssertEqual(try JSONDecoder().decode(GameIntent.self, from: JSONEncoder().encode(intent)), intent)
        }

        var state = makeState()
        state.players[1].jailTurn = 2
        XCTAssertEqual(try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state)), state)

        for error in [GameRuleError.alreadyInJail(ana.id), .notInJail(luis.id)] {
            XCTAssertEqual(try JSONDecoder().decode(GameRuleError.self, from: JSONEncoder().encode(error)), error)
        }
    }
}
