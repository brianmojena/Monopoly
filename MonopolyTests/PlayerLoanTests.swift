import XCTest
@testable import Monopoly

/// GAME_RULES section 4.9: loans between players with agreed terms.
final class PlayerLoanTests: XCTestCase {
    private var ana = Player(name: "Ana", balance: 2_000)
    private var luis = Player(name: "Luis", balance: 100)
    private var eva = Player(name: "Eva", balance: 1_000)

    private func makeState(luisBalance: Int = 100) -> GameState {
        luis.balance = luisBalance
        let street = Property(name: "Street", colorGroup: .brown, purchasePrice: 200, mortgageValue: 100, baseRent: 200, ownerID: luis.id)
        let avenue = Property(name: "Avenue", colorGroup: .pink, purchasePrice: 300, mortgageValue: 150, baseRent: 100, ownerID: eva.id)
        return GameState(players: [ana, luis, eva], properties: [street, avenue])
    }

    private func loanDeal(_ loan: PlayerLoan, proposerID: UUID? = nil) -> MarketDeal {
        MarketDeal(
            proposerID: proposerID ?? loan.lenderID,
            transfers: [DealTransfer(from: .player(loan.lenderID), to: .player(loan.borrowerID), asset: .money(loan.principal))],
            proposedLoan: loan
        )
    }

    /// Proposes and accepts the loan, so it is active.
    private func lend(_ loan: PlayerLoan, in state: GameState) throws -> GameState {
        let deal = loanDeal(loan)
        let proposed = try GameRules.proposeDeal(in: state, deal: deal, proposerID: loan.lenderID)
        return try GameRules.acceptDeal(in: proposed, dealID: deal.id, playerID: loan.borrowerID)
    }

    private func balance(_ player: Player, in state: GameState) -> Int {
        state.players.first(where: { $0.id == player.id })?.balance ?? -1
    }

    /// Ends every player's turn once, closing the current round.
    private func finishRound(_ state: GameState) -> GameState {
        var updated = state
        updated.currentPlayerID = state.players.last?.id
        return GameRules.advanceTurn(in: updated)
    }

    // MARK: Creating

    func testSettledLoanPaysThePrincipalAndOwesItWithInterest() throws {
        let loan = PlayerLoan(lenderID: ana.id, borrowerID: luis.id, principal: 500, interestPercentage: 20, goPayment: 100)

        let state = try lend(loan, in: makeState())

        XCTAssertEqual(balance(ana, in: state), 1_500)
        XCTAssertEqual(balance(luis, in: state), 600)
        XCTAssertEqual(state.playerLoans.count, 1)
        XCTAssertEqual(state.playerLoans[0].remainingDebt, 600)
        XCTAssertTrue(state.marketDeals.isEmpty)
    }

    func testInterestRoundsUp() {
        XCTAssertEqual(PlayerLoan.totalDebt(principal: 105, interestPercentage: 10), 105 + 11)
    }

    func testTheBorrowerCanAskForTheLoan() throws {
        let loan = PlayerLoan(lenderID: ana.id, borrowerID: luis.id, principal: 300, goPayment: 50)
        let deal = loanDeal(loan, proposerID: luis.id)

        let proposed = try GameRules.proposeDeal(in: makeState(), deal: deal, proposerID: luis.id)
        let state = try GameRules.acceptDeal(in: proposed, dealID: deal.id, playerID: ana.id)

        XCTAssertEqual(state.playerLoans.map(\.borrowerID), [luis.id])
    }

    func testLoanNeedsAWayToBeRepaid() {
        let loan = PlayerLoan(lenderID: ana.id, borrowerID: luis.id, principal: 300)

        XCTAssertThrowsError(try lend(loan, in: makeState())) { error in
            XCTAssertEqual(error as? GameRuleError, .invalidLoanTerms)
        }
    }

    func testLoanRejectsBadTerms() {
        let state = makeState()
        let badLoans = [
            PlayerLoan(lenderID: ana.id, borrowerID: luis.id, principal: 300, interestPercentage: 101, goPayment: 50),
            PlayerLoan(lenderID: ana.id, borrowerID: luis.id, principal: 300, goPayment: 0),
            PlayerLoan(lenderID: ana.id, borrowerID: luis.id, principal: 300, rentPercentage: 3),
            PlayerLoan(lenderID: ana.id, borrowerID: luis.id, principal: 300, dueRound: state.round - 1)
        ]
        for loan in badLoans {
            XCTAssertThrowsError(try lend(loan, in: state)) { error in
                XCTAssertEqual(error as? GameRuleError, .invalidLoanTerms)
            }
        }
    }

    func testThePrincipalMustBeTheTransferBetweenThem() {
        let loan = PlayerLoan(lenderID: ana.id, borrowerID: luis.id, principal: 300, goPayment: 50)
        var deal = loanDeal(loan)
        deal.transfers = [DealTransfer(from: .player(ana.id), to: .player(luis.id), asset: .money(200))]

        XCTAssertThrowsError(try GameRules.proposeDeal(in: makeState(), deal: deal, proposerID: ana.id)) { error in
            XCTAssertEqual(error as? GameRuleError, .invalidDeal)
        }
    }

    func testALoanIsOnlyBetweenItsTwoPlayers() {
        let loan = PlayerLoan(lenderID: ana.id, borrowerID: luis.id, principal: 300, goPayment: 50)
        var deal = loanDeal(loan)
        deal.transfers.append(DealTransfer(from: .player(eva.id), to: .player(ana.id), asset: .money(10)))

        XCTAssertThrowsError(try GameRules.proposeDeal(in: makeState(), deal: deal, proposerID: ana.id)) { error in
            XCTAssertEqual(error as? GameRuleError, .invalidDeal)
        }
    }

    // MARK: Repaying

    func testEachGoPaysTheInstallmentUntilTheLoanIsPaid() throws {
        let loan = PlayerLoan(lenderID: ana.id, borrowerID: luis.id, principal: 300, interestPercentage: 10, goPayment: 200)
        var state = try lend(loan, in: makeState(luisBalance: 0))

        state = try GameRules.collectSalary(in: state, playerID: luis.id, amount: 200)
        XCTAssertEqual(state.playerLoans.first?.remainingDebt, 130)
        XCTAssertEqual(balance(luis, in: state), 300)

        state = try GameRules.collectSalary(in: state, playerID: luis.id, amount: 200)
        XCTAssertTrue(state.playerLoans.isEmpty)
        XCTAssertEqual(balance(luis, in: state), 370)
        XCTAssertEqual(balance(ana, in: state), 2_000 - 300 + 330)
    }

    func testGoPaymentNeverLeavesTheBalanceNegative() throws {
        let loan = PlayerLoan(lenderID: ana.id, borrowerID: luis.id, principal: 100, goPayment: 500)
        var state = try lend(loan, in: makeState(luisBalance: 0))
        state.players[1].balance = 0

        state = try GameRules.collectSalary(in: state, playerID: luis.id, amount: 60)

        XCTAssertEqual(balance(luis, in: state), 0)
        XCTAssertEqual(state.playerLoans.first?.remainingDebt, 40)
    }

    func testRentCutGoesToTheLenderUntilPaid() throws {
        let loan = PlayerLoan(lenderID: ana.id, borrowerID: luis.id, principal: 60, rentPercentage: 50)
        let state = try lend(loan, in: makeState())
        let rent = try GameRules.rentAmount(for: state.properties[0], in: state, ownerID: luis.id)

        let result = try GameRules.collectRent(in: state, from: eva.id, propertyID: state.properties[0].id).state

        let cut = min(rent / 2, 60)
        XCTAssertEqual(balance(ana, in: result), 2_000 - 60 + cut)
        XCTAssertEqual(balance(luis, in: result), 100 + 60 + rent - cut)
        XCTAssertEqual(result.playerLoans.first?.remainingDebt ?? 0, 60 - cut)
    }

    func testEarlyPaymentAndForgiveness() throws {
        let loan = PlayerLoan(lenderID: ana.id, borrowerID: luis.id, principal: 300, goPayment: 50)
        let state = try lend(loan, in: makeState())

        let paid = try GameRules.payPlayerLoan(in: state, playerID: luis.id, loanID: loan.id, amount: 100)
        XCTAssertEqual(paid.playerLoans.first?.remainingDebt, 200)
        XCTAssertEqual(balance(ana, in: paid), 1_800)

        let paidOff = try GameRules.payPlayerLoan(in: paid, playerID: luis.id, loanID: loan.id, amount: 200)
        XCTAssertTrue(paidOff.playerLoans.isEmpty)

        XCTAssertThrowsError(try GameRules.payPlayerLoan(in: state, playerID: luis.id, loanID: loan.id, amount: 301))
        XCTAssertThrowsError(try GameRules.payPlayerLoan(in: state, playerID: ana.id, loanID: loan.id, amount: 10)) { error in
            XCTAssertEqual(error as? GameRuleError, .playerLoanNotFound(loan.id))
        }

        let forgiven = try GameRules.forgivePlayerLoan(in: state, playerID: ana.id, loanID: loan.id)
        XCTAssertTrue(forgiven.playerLoans.isEmpty)
        XCTAssertThrowsError(try GameRules.forgivePlayerLoan(in: state, playerID: luis.id, loanID: loan.id))
    }

    // MARK: Due date and collateral

    func testDueLoanIsPaidInFullWhenTheBorrowerCan() throws {
        let loan = PlayerLoan(lenderID: ana.id, borrowerID: luis.id, principal: 300, dueRound: 1)
        let state = finishRound(try lend(loan, in: makeState()))

        XCTAssertTrue(state.playerLoans.isEmpty)
        XCTAssertEqual(balance(luis, in: state), 100)
        XCTAssertEqual(state.round, 2)
    }

    func testUnpaidDueLoanHandsOverTheCollateral() throws {
        let base = makeState()
        let loan = PlayerLoan(
            lenderID: ana.id, borrowerID: luis.id, principal: 300, dueRound: 1,
            collateral: LoanCollateral(propertyID: base.properties[0].id, shares: 4)
        )
        var state = try lend(loan, in: base)
        state.players[1].balance = 50

        state = finishRound(state)

        XCTAssertTrue(state.playerLoans.isEmpty)
        XCTAssertEqual(balance(luis, in: state), 0)
        XCTAssertEqual(balance(ana, in: state), 2_000 - 300 + 50)
        XCTAssertEqual(state.properties[0].shares(of: ana.id), 4)
        XCTAssertEqual(state.properties[0].shares(of: luis.id), 6)
    }

    func testUnpaidDueLoanWithoutCollateralGoesOverdueAndTakesEveryGo() throws {
        let loan = PlayerLoan(lenderID: ana.id, borrowerID: luis.id, principal: 300, dueRound: 1)
        var state = try lend(loan, in: makeState())
        state.players[1].balance = 100

        state = finishRound(state)
        XCTAssertEqual(state.playerLoans.first?.isOverdue, true)
        XCTAssertEqual(state.playerLoans.first?.remainingDebt, 200)

        state = try GameRules.collectSalary(in: state, playerID: luis.id, amount: 150)
        XCTAssertEqual(state.playerLoans.first?.remainingDebt, 50)
        XCTAssertEqual(balance(luis, in: state), 0)
    }

    func testPledgedSharesCannotBeTraded() throws {
        let base = makeState()
        let propertyID = base.properties[0].id
        let loan = PlayerLoan(
            lenderID: ana.id, borrowerID: luis.id, principal: 300, dueRound: 3,
            collateral: LoanCollateral(propertyID: propertyID, shares: 8)
        )
        let state = try lend(loan, in: base)

        let fine = MarketDeal(proposerID: luis.id, transfers: [
            DealTransfer(from: .player(luis.id), to: .player(eva.id), asset: .shares(propertyID: propertyID, count: 2))
        ])
        XCTAssertNoThrow(try GameRules.proposeDeal(in: state, deal: fine, proposerID: luis.id))

        let tooMany = MarketDeal(proposerID: luis.id, transfers: [
            DealTransfer(from: .player(luis.id), to: .player(eva.id), asset: .shares(propertyID: propertyID, count: 3))
        ])
        XCTAssertThrowsError(try GameRules.proposeDeal(in: state, deal: tooMany, proposerID: luis.id)) { error in
            XCTAssertEqual(error as? GameRuleError, .notEnoughShares(propertyID: propertyID, playerID: luis.id))
        }

        let secondLoan = PlayerLoan(
            lenderID: eva.id, borrowerID: luis.id, principal: 100, dueRound: 3,
            collateral: LoanCollateral(propertyID: propertyID, shares: 3)
        )
        XCTAssertThrowsError(try lend(secondLoan, in: state)) { error in
            XCTAssertEqual(error as? GameRuleError, .notEnoughShares(propertyID: propertyID, playerID: luis.id))
        }
    }

    // MARK: Bankruptcy and net worth

    func testBankruptBorrowersLenderTakesTheCollateralFirst() throws {
        let base = makeState()
        let propertyID = base.properties[0].id
        let loan = PlayerLoan(
            lenderID: ana.id, borrowerID: luis.id, principal: 300, dueRound: 5,
            collateral: LoanCollateral(propertyID: propertyID, shares: 3)
        )
        let state = try lend(loan, in: base)

        let result = try GameRules.declareBankruptcy(in: state, playerID: luis.id, creditor: .player(eva.id))

        XCTAssertTrue(result.playerLoans.isEmpty)
        XCTAssertEqual(result.properties[0].shares(of: ana.id), 3)
        XCTAssertEqual(result.properties[0].shares(of: eva.id), 7)
    }

    func testBankruptLendersLoansAreCancelled() throws {
        let loan = PlayerLoan(lenderID: ana.id, borrowerID: luis.id, principal: 300, goPayment: 50)
        let state = try lend(loan, in: makeState())

        let result = try GameRules.declareBankruptcy(in: state, playerID: ana.id, creditor: .bank)

        XCTAssertTrue(result.playerLoans.isEmpty)
    }

    func testNetWorthCountsLoans() throws {
        let base = makeState()
        let loan = PlayerLoan(lenderID: ana.id, borrowerID: luis.id, principal: 500, interestPercentage: 20, goPayment: 100)
        let state = try lend(loan, in: base)

        XCTAssertEqual(try GameRules.netWorth(of: ana.id, in: state), try GameRules.netWorth(of: ana.id, in: base) + 100)
        XCTAssertEqual(try GameRules.netWorth(of: luis.id, in: state), try GameRules.netWorth(of: luis.id, in: base) - 100)
    }

    // MARK: Networking

    func testLoanDealsAndIntentsRoundTripThroughJSON() throws {
        let loan = PlayerLoan(
            lenderID: ana.id, borrowerID: luis.id, principal: 300, interestPercentage: 15,
            goPayment: 50, rentPercentage: 25, dueRound: 4,
            collateral: LoanCollateral(propertyID: UUID(), shares: 2)
        )
        let intents: [GameIntent] = [
            .proposeDeal(loanDeal(loan)),
            .payPlayerLoan(playerID: luis.id, loanID: loan.id, amount: 20),
            .forgivePlayerLoan(playerID: ana.id, loanID: loan.id)
        ]
        for intent in intents {
            let decoded = try JSONDecoder().decode(GameIntent.self, from: JSONEncoder().encode(intent))
            XCTAssertEqual(decoded, intent)
        }

        var state = makeState()
        state.playerLoans = [loan]
        XCTAssertEqual(try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state)), state)

        for error in [GameRuleError.playerLoanNotFound(loan.id), .invalidLoanTerms] {
            XCTAssertEqual(try JSONDecoder().decode(GameRuleError.self, from: JSONEncoder().encode(error)), error)
        }
    }
}
