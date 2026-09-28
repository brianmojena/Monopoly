import XCTest
@testable import Monopoly

/// GAME_RULES section 4.10: variable and fixed savings accounts.
final class SavingsTests: XCTestCase {
    private let ana = Player(name: "Ana", balance: 2_000)
    private let luis = Player(name: "Luis", balance: 500)

    private func makeState(rules: Set<HouseRule> = [.savingsAccounts, .creditCards]) -> GameState {
        GameState(players: [ana, luis], properties: [], activeHouseRules: rules)
    }

    private func player(_ id: UUID, in state: GameState) -> Player {
        state.players.first(where: { $0.id == id })!
    }

    private func passGo(_ state: GameState, salary: Int = 0) throws -> GameState {
        try GameRules.collectSalary(in: state, playerID: ana.id, amount: salary)
    }

    func testSavingsNeedTheRule() {
        XCTAssertThrowsError(try GameRules.depositInVariableSavings(in: makeState(rules: []), playerID: ana.id, amount: 100)) { error in
            XCTAssertEqual(error as? GameRuleError, .savingsDisabled)
        }
    }

    func testDepositMovesCashIntoTheVariableAccount() throws {
        let state = try GameRules.depositInVariableSavings(in: makeState(), playerID: ana.id, amount: 500)
        XCTAssertEqual(player(ana.id, in: state).balance, 1_500)
        XCTAssertEqual(player(ana.id, in: state).savings.variableBalance, 500)
        XCTAssertEqual(try GameRules.netWorth(of: ana.id, in: state), 2_000)
    }

    func testVariableInterestGoesToCashAndClimbsToFiftyPercent() throws {
        var state = try GameRules.depositInVariableSavings(in: makeState(), playerID: ana.id, amount: 1_000)
        var cash = 1_000
        for rate in [10, 20, 30, 40, 50, 50] {
            state = try passGo(state)
            cash += 1_000 * rate / 100
            XCTAssertEqual(player(ana.id, in: state).balance, cash)
            XCTAssertEqual(player(ana.id, in: state).savings.variableBalance, 1_000)
        }
    }

    func testWithdrawingResetsTheVariableRate() throws {
        var state = try GameRules.depositInVariableSavings(in: makeState(), playerID: ana.id, amount: 1_000)
        state = try passGo(state)
        state = try passGo(state)
        XCTAssertEqual(player(ana.id, in: state).savings.variableStreak, 2)

        state = try GameRules.withdrawFromVariableSavings(in: state, playerID: ana.id, amount: 200)
        XCTAssertEqual(player(ana.id, in: state).savings.variableBalance, 800)
        let cash = player(ana.id, in: state).balance
        state = try passGo(state)
        XCTAssertEqual(player(ana.id, in: state).balance, cash + 80)
    }

    func testDepositingDoesNotResetTheVariableRate() throws {
        var state = try GameRules.depositInVariableSavings(in: makeState(), playerID: ana.id, amount: 500)
        state = try passGo(state)
        state = try GameRules.depositInVariableSavings(in: state, playerID: ana.id, amount: 500)
        let cash = player(ana.id, in: state).balance
        state = try passGo(state)
        XCTAssertEqual(player(ana.id, in: state).balance, cash + 200)
    }

    func testAnEmptyVariableAccountDoesNotClimb() throws {
        var state = try passGo(makeState())
        state = try passGo(state)
        state = try GameRules.depositInVariableSavings(in: state, playerID: ana.id, amount: 1_000)
        let cash = player(ana.id, in: state).balance
        state = try passGo(state)
        XCTAssertEqual(player(ana.id, in: state).balance, cash + 100)
    }

    func testCannotWithdrawMoreThanSaved() throws {
        let state = try GameRules.depositInVariableSavings(in: makeState(), playerID: ana.id, amount: 100)
        XCTAssertThrowsError(try GameRules.withdrawFromVariableSavings(in: state, playerID: ana.id, amount: 101))
    }

    func testFixedDepositPaysRisingInterestAndReturnsTheMoney() throws {
        var state = try GameRules.openFixedDeposit(in: makeState(), playerID: ana.id, amount: 1_000, terms: 3)
        XCTAssertEqual(player(ana.id, in: state).balance, 1_000)

        state = try passGo(state)
        XCTAssertEqual(player(ana.id, in: state).balance, 1_200)
        state = try passGo(state)
        XCTAssertEqual(player(ana.id, in: state).balance, 1_550)
        XCTAssertEqual(player(ana.id, in: state).savings.fixedDeposits.first?.gosRemaining, 1)

        state = try passGo(state)
        XCTAssertEqual(player(ana.id, in: state).balance, 1_550 + 500 + 1_000)
        XCTAssertTrue(player(ana.id, in: state).savings.fixedDeposits.isEmpty)
        XCTAssertEqual(GameRules.fixedSavingsTotalInterest(amount: 1_000, terms: 3), 1_050)
    }

    func testFixedDepositTermsAreOneToFive() {
        for terms in [0, 6] {
            XCTAssertThrowsError(try GameRules.openFixedDeposit(in: makeState(), playerID: ana.id, amount: 100, terms: terms)) { error in
                XCTAssertEqual(error as? GameRuleError, .invalidSavingsTerm(terms))
            }
        }
    }

    func testCannotSaveMoneyOwedOnTheCreditCard() throws {
        let state = try GameRules.borrowOnCreditCard(in: makeState(), playerID: ana.id, amount: 500)
        let owed = player(ana.id, in: state).creditCardDebt
        let savable = 2_500 - owed
        XCTAssertEqual(GameRules.savableAmount(for: ana.id, in: state), savable)

        XCTAssertThrowsError(try GameRules.openFixedDeposit(in: state, playerID: ana.id, amount: savable + 1, terms: 2)) { error in
            XCTAssertEqual(error as? GameRuleError, .savingsBlockedByDebt(savable: savable))
        }
        XCTAssertNoThrow(try GameRules.depositInVariableSavings(in: state, playerID: ana.id, amount: savable))
    }

    func testCannotSaveMoneyOwedToAnotherPlayer() throws {
        var state = makeState()
        state.playerLoans = [PlayerLoan(lenderID: luis.id, borrowerID: ana.id, principal: 1_500, dueRound: 3)]
        XCTAssertEqual(GameRules.savableAmount(for: ana.id, in: state), 500)
        XCTAssertThrowsError(try GameRules.depositInVariableSavings(in: state, playerID: ana.id, amount: 501))
    }

    func testMaturedDepositCoversTheSameGosInstallments() throws {
        var state = try GameRules.openFixedDeposit(in: makeState(), playerID: luis.id, amount: 500, terms: 1)
        state.players[1].creditCardLoans = [CreditCardLoan(principal: 100, installmentsRemaining: 1)]
        state = try GameRules.collectSalary(in: state, playerID: luis.id, amount: 0)
        XCTAssertTrue(player(luis.id, in: state).creditCardLoans.isEmpty)
        XCTAssertEqual(player(luis.id, in: state).creditHistory.missedPayments, 0)
    }

    func testBankruptcyHandsSavingsToTheCreditor() throws {
        var state = try GameRules.openFixedDeposit(in: makeState(), playerID: ana.id, amount: 1_000, terms: 5)
        state = try GameRules.depositInVariableSavings(in: state, playerID: ana.id, amount: 400)
        state = try GameRules.declareBankruptcy(in: state, playerID: ana.id, creditor: .player(luis.id))
        XCTAssertEqual(player(luis.id, in: state).balance, 2_500)
        XCTAssertTrue(player(ana.id, in: state).savings.isEmpty)
    }

    func testLobbyTurnsSavingsOnInBothModes() {
        let players = [LobbyPlayer(name: "Ana", isHostControlled: true), LobbyPlayer(name: "Luis", isHostControlled: false)]
        for mode in [GameMode.classic, .monopolife] {
            let lobby = Lobby(players: players, creditCardsEnabled: false, savingsEnabled: true, gameMode: mode)
            XCTAssertTrue(lobby.makeGameState(initialBalance: 1_500, properties: []).activeHouseRules.contains(.savingsAccounts))
        }
    }

    func testSavingsSurviveEncoding() throws {
        var state = try GameRules.openFixedDeposit(in: makeState(), playerID: ana.id, amount: 300, terms: 4)
        state = try GameRules.depositInVariableSavings(in: state, playerID: ana.id, amount: 200)
        let decoded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(decoded, state)

        let intent = GameIntent.openFixedDeposit(playerID: ana.id, amount: 300, terms: 4)
        XCTAssertEqual(try JSONDecoder().decode(GameIntent.self, from: JSONEncoder().encode(intent)), intent)
    }
}
