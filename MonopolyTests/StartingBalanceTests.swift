import XCTest
@testable import Monopoly

/// GAME_RULES section 8.6: starting balance and spread chosen in the lobby.
final class StartingBalanceTests: XCTestCase {
    private func players(_ count: Int) -> [LobbyPlayer] {
        (1...count).map { LobbyPlayer(name: "J\($0)", isHostControlled: true) }
    }

    func testWithoutChangesEveryoneStartsWithTheModeDefault() {
        let classic = Lobby(players: players(3))
        let monopolife = Lobby(players: players(3), gameMode: .monopolife)

        XCTAssertEqual(classic.makeGameState(initialBalance: 1500, properties: []).players.map(\.balance), [1500, 1500, 1500])
        XCTAssertEqual(
            monopolife.makeGameState(initialBalance: 1500, properties: []).players.map(\.balance),
            Array(repeating: MonopolifeState.initialBalance, count: 3)
        )
    }

    func testHostChosenBalanceReplacesTheDefaultInBothModes() {
        for mode in [GameMode.classic, .monopolife] {
            let lobby = Lobby(players: players(2), gameMode: mode, startingBalance: 3000)

            XCTAssertEqual(lobby.makeGameState(initialBalance: 1500, properties: []).players.map(\.balance), [3000, 3000])
        }
    }

    func testSpreadGivesEveryPlayerADifferentStepInRandomOrder() {
        let lobby = Lobby(players: players(4), startingBalance: 1600, startingBalanceSpread: 100)
        var orders = Set<[Int]>()

        for seed in 0..<20 {
            var generator = SeededRandom(state: UInt64(seed))
            let balances = lobby.makeGameState(initialBalance: 1500, properties: [], using: &generator).players.map(\.balance)
            XCTAssertEqual(balances.sorted(), [1600, 1700, 1800, 1900])
            orders.insert(balances)
        }

        XCTAssertGreaterThan(orders.count, 1, "Who starts richer is drawn, not the turn order.")
    }

    func testSpreadOfTwoHundred() {
        let lobby = Lobby(players: players(3), startingBalanceSpread: 200)

        let balances = lobby.makeGameState(initialBalance: 1500, properties: []).players.map(\.balance)

        XCTAssertEqual(balances.sorted(), [1500, 1700, 1900])
        XCTAssertEqual(lobby.startingBalances(classicDefault: 1500), [1500, 1700, 1900])
    }

    func testSpreadDoesNotChangeTheDrawnMonopolifeRoles() {
        let even = Lobby(players: players(3), gameMode: .monopolife)
        var spread = even
        spread.startingBalanceSpread = 100
        var evenGenerator = SeededRandom(state: 7)
        var spreadGenerator = SeededRandom(state: 7)

        let evenState = even.makeGameState(initialBalance: 1500, properties: [], using: &evenGenerator)
        let spreadState = spread.makeGameState(initialBalance: 1500, properties: [], using: &spreadGenerator)

        XCTAssertEqual(evenState.monopolife, spreadState.monopolife)
    }

    func testLobbySavedWithoutStartingBalanceDecodesWithDefaults() throws {
        let json = #"{"players":[],"creditCardsEnabled":true}"#

        let lobby = try JSONDecoder().decode(Lobby.self, from: Data(json.utf8))

        XCTAssertNil(lobby.startingBalance)
        XCTAssertEqual(lobby.startingBalanceSpread, 0)
    }

    func testStartingBalanceRoundTripsThroughJSON() throws {
        let lobby = Lobby(players: players(2), startingBalance: 2500, startingBalanceSpread: 200)

        XCTAssertEqual(try JSONDecoder().decode(Lobby.self, from: JSONEncoder().encode(lobby)), lobby)
    }
}
