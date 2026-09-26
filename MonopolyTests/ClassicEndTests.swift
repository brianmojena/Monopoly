import XCTest
@testable import Monopoly

/// GAME_RULES section 7: a Classic game ends by bankruptcies or at a net worth goal.
final class ClassicEndTests: XCTestCase {
    private let ana = Player(name: "Ana", balance: 1_500)
    private let luis = Player(name: "Luis", balance: 900)
    private let eva = Player(name: "Eva", balance: 300)

    private func makeState(_ conditions: ClassicEndConditions = ClassicEndConditions()) -> GameState {
        GameState(players: [ana, luis, eva], properties: [], currentPlayerID: ana.id, endConditions: conditions)
    }

    private func bankrupt(_ players: [Player], in state: GameState) throws -> GameState {
        var updated = state
        for player in players {
            updated = try GameRules.declareBankruptcy(in: updated, playerID: player.id, creditor: .bank)
        }
        GameRules.checkClassicEnd(in: &updated)
        return updated
    }

    func testByDefaultTheLastPlayerStandingWins() throws {
        let oneDown = try bankrupt([eva], in: makeState())
        XCTAssertNil(oneDown.classicResult)

        let state = try bankrupt([luis], in: oneDown)
        XCTAssertEqual(state.classicResult?.winnerIDs, [ana.id])
        XCTAssertEqual(state.classicResult?.reason, .lastPlayerStanding)
        XCTAssertNil(state.currentPlayerID)
        XCTAssertTrue(state.isFinished)
    }

    func testEnoughBankruptciesHandTheWinToTheRichest() throws {
        let state = try bankrupt([eva], in: makeState(ClassicEndConditions(bankruptciesToEnd: 1)))

        XCTAssertEqual(state.classicResult?.winnerIDs, [ana.id])
        XCTAssertEqual(state.classicResult?.reason, .bankruptcies)
    }

    func testTiedNetWorthSharesTheWin() throws {
        var state = makeState(ClassicEndConditions(bankruptciesToEnd: 1))
        state.players[1].balance = ana.balance

        state = try bankrupt([eva], in: state)

        XCTAssertEqual(Set(state.classicResult?.winnerIDs ?? []), [ana.id, luis.id])
    }

    func testReachingTheNetWorthGoalWinsRightAway() throws {
        var state = makeState(ClassicEndConditions(netWorthGoal: 2_000))
        GameRules.checkClassicEnd(in: &state)
        XCTAssertNil(state.classicResult)

        state = try GameRules.collectSalary(in: state, playerID: luis.id, amount: 1_100)
        GameRules.checkClassicEnd(in: &state)

        XCTAssertEqual(state.classicResult?.winnerIDs, [luis.id])
        XCTAssertEqual(state.classicResult?.reason, .netWorthGoal)
        XCTAssertThrowsError(try GameRules.requireGameNotFinished(in: state)) { error in
            XCTAssertEqual(error as? GameRuleError, .gameFinished)
        }
    }

    func testBankruptPlayersNeverReachTheGoal() throws {
        var state = makeState(ClassicEndConditions(netWorthGoal: 100))
        state.players = [ana, luis, eva].map { player in
            var player = player
            player.status = .bankrupt
            return player
        }
        state.players[0].status = .active
        state.players[1].status = .active

        GameRules.checkClassicEnd(in: &state)

        XCTAssertEqual(state.classicResult?.reason, .netWorthGoal)
        XCTAssertEqual(state.classicResult?.winnerIDs, [ana.id])
    }

    func testMonopolifeIgnoresClassicEndings() throws {
        var state = makeState(ClassicEndConditions(netWorthGoal: 100, bankruptciesToEnd: 1))
        state.mode = .monopolife
        state.monopolife = MonopolifeState(roundLimit: 10, profiles: [:], lifeDeck: [])

        GameRules.checkClassicEnd(in: &state)

        XCTAssertNil(state.classicResult)
    }

    func testLobbyCarriesTheConditionsAndAnImpossibleCountMeansLastStanding() {
        let players = [LobbyPlayer(name: "Ana", isHostControlled: true), LobbyPlayer(name: "Luis", isHostControlled: false)]
        let lobby = Lobby(players: players, endConditions: ClassicEndConditions(netWorthGoal: 8_000, bankruptciesToEnd: 3))

        let state = lobby.makeGameState(initialBalance: 1_500, properties: [])
        XCTAssertEqual(state.endConditions, ClassicEndConditions(netWorthGoal: 8_000, bankruptciesToEnd: nil))

        var monopolife = lobby
        monopolife.gameMode = .monopolife
        XCTAssertEqual(monopolife.makeGameState(initialBalance: 1_500, properties: []).endConditions, ClassicEndConditions())
    }

    func testOldLobbiesAndGamesDecodeWithTheDefaults() throws {
        let lobby = try JSONDecoder().decode(Lobby.self, from: Data(#"{"players":[],"creditCardsEnabled":true}"#.utf8))
        XCTAssertEqual(lobby.endConditions, ClassicEndConditions())

        var state = makeState(ClassicEndConditions(netWorthGoal: 5_000, bankruptciesToEnd: 1))
        state.classicResult = ClassicResult(winnerIDs: [ana.id], reason: .bankruptcies, round: 7)
        XCTAssertEqual(try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state)), state)
    }
}
