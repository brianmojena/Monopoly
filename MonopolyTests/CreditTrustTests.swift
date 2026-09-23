import XCTest
@testable import Monopoly

final class CreditTrustTests: XCTestCase {
    private func makeState(balance: Int = 1000, history: CreditHistory = CreditHistory(), loans: [CreditCardLoan] = []) -> (GameState, UUID) {
        let ana = Player(name: "Ana", balance: balance, creditCardLoans: loans, creditHistory: history)
        let luis = Player(name: "Luis", balance: 1000)
        let state = GameState(players: [ana, luis], properties: [], currentPlayerID: ana.id, activeHouseRules: [.creditCards])
        return (state, ana.id)
    }

    private func loan(debt: Int, installments: Int = 1, postponements: Int = 0) -> CreditCardLoan {
        CreditCardLoan(remainingDebt: debt, installmentsRemaining: installments, postponementsRemaining: postponements)
    }

    // MARK: Limit

    func testLimitMovesTwentyPointsPerPaidLoanAndMissedPaymentBetweenZeroAndOneHundred() {
        XCTAssertEqual(GameRules.creditLimitPercentage(for: CreditHistory()), 50)
        XCTAssertEqual(GameRules.creditLimitPercentage(for: CreditHistory(paidOffLoans: 1)), 70)
        XCTAssertEqual(GameRules.creditLimitPercentage(for: CreditHistory(paidOffLoans: 2)), 90)
        XCTAssertEqual(GameRules.creditLimitPercentage(for: CreditHistory(paidOffLoans: 5)), 100)
        XCTAssertEqual(GameRules.creditLimitPercentage(for: CreditHistory(missedPayments: 1)), 30)
        XCTAssertEqual(GameRules.creditLimitPercentage(for: CreditHistory(paidOffLoans: 1, missedPayments: 1)), 50)
        XCTAssertEqual(GameRules.creditLimitPercentage(for: CreditHistory(missedPayments: 5)), 0)
    }

    func testAvailableCreditUsesTheTrustLimit() throws {
        let (fresh, ana) = makeState()
        XCTAssertEqual(try GameRules.availableCredit(for: ana, in: fresh), 500)

        let (trusted, trustedAna) = makeState(history: CreditHistory(paidOffLoans: 1))
        XCTAssertEqual(try GameRules.availableCredit(for: trustedAna, in: trusted), 700)

        let (doubted, doubtedAna) = makeState(history: CreditHistory(missedPayments: 1))
        XCTAssertEqual(try GameRules.availableCredit(for: doubtedAna, in: doubted), 300)
    }

    // MARK: Paying off

    func testPayingALoanOffEarlyRaisesTrust() throws {
        let (base, ana) = makeState()
        var state = try GameRules.borrowOnCreditCard(in: base, playerID: ana, amount: 100, installments: 2)
        let loanID = try XCTUnwrap(state.players[0].creditCardLoans.first?.id)

        state = try GameRules.payCreditCard(in: state, playerID: ana, loanID: loanID, amount: 50)
        XCTAssertEqual(state.players[0].creditHistory.paidOffLoans, 0)

        state = try GameRules.payCreditCard(in: state, playerID: ana, loanID: loanID, amount: 60)
        XCTAssertEqual(state.players[0].creditHistory.paidOffLoans, 1)
        XCTAssertTrue(state.players[0].creditCardLoans.isEmpty)
    }

    func testPayingALoanOffAtGoRaisesTrust() throws {
        let (state, ana) = makeState(loans: [loan(debt: 110)])

        let result = try GameRules.collectSalary(in: state, playerID: ana, amount: 200)

        XCTAssertEqual(result.players[0].creditHistory, CreditHistory(paidOffLoans: 1, missedPayments: 0))
    }

    // MARK: Simultaneous loans

    func testOnlyOneLoanUntilOneIsPaidOff() throws {
        let (base, ana) = makeState()
        let state = try GameRules.borrowOnCreditCard(in: base, playerID: ana, amount: 100, installments: 1)

        XCTAssertThrowsError(try GameRules.borrowOnCreditCard(in: state, playerID: ana, amount: 50, installments: 1)) { error in
            XCTAssertEqual(error as? GameRuleError, .creditCardLoanLimitReached(1))
        }
    }

    func testTwoLoansAtOnceAfterPayingOneOff() throws {
        let (base, ana) = makeState(balance: 2000)
        var state = try GameRules.borrowOnCreditCard(in: base, playerID: ana, amount: 100, installments: 1)
        let firstLoan = try XCTUnwrap(state.players[0].creditCardLoans.first?.id)
        state = try GameRules.payCreditCard(in: state, playerID: ana, loanID: firstLoan, amount: 110)

        state = try GameRules.borrowOnCreditCard(in: state, playerID: ana, amount: 100, installments: 1)
        state = try GameRules.borrowOnCreditCard(in: state, playerID: ana, amount: 100, installments: 1)
        XCTAssertEqual(state.players[0].creditCardLoans.count, 2)

        XCTAssertThrowsError(try GameRules.borrowOnCreditCard(in: state, playerID: ana, amount: 100, installments: 1)) { error in
            XCTAssertEqual(error as? GameRuleError, .creditCardLoanLimitReached(2))
        }
    }

    // MARK: Missed payments

    func testShortInstallmentAtGoIsAMissedPayment() throws {
        let (state, ana) = makeState(balance: 0, loans: [loan(debt: 500)])

        let result = try GameRules.collectSalary(in: state, playerID: ana, amount: 200)

        XCTAssertEqual(result.players[0].creditHistory.missedPayments, 1)
        XCTAssertEqual(result.players[0].balance, 0)
        XCTAssertEqual(result.players[0].creditCardLoans.first?.remainingDebt, 300)
    }

    func testPostponingIsNotAMissedPayment() throws {
        let postponed = loan(debt: 500, installments: 2, postponements: 1)
        let (state, ana) = makeState(balance: 0, loans: [postponed])

        let result = try GameRules.collectSalary(in: state, playerID: ana, amount: 0, postponedLoanIDs: [postponed.id])

        XCTAssertEqual(result.players[0].creditHistory.missedPayments, 0)
    }

    func testSeveralShortInstallmentsInOneGoCountOnce() throws {
        let (state, ana) = makeState(balance: 0, loans: [loan(debt: 500), loan(debt: 500)])

        let result = try GameRules.collectSalary(in: state, playerID: ana, amount: 100)

        XCTAssertEqual(result.players[0].creditHistory.missedPayments, 1)
    }

    func testCoveredInstallmentIsNotAMissedPayment() throws {
        let (state, ana) = makeState(balance: 0, loans: [loan(debt: 500, installments: 5)])

        let result = try GameRules.collectSalary(in: state, playerID: ana, amount: 200)

        XCTAssertEqual(result.players[0].creditHistory, CreditHistory())
    }

    func testTwoMissedPaymentsCutCreditButLoansKeepBeingCharged() throws {
        let (state, ana) = makeState(balance: 0, loans: [loan(debt: 1000)])

        var result = try GameRules.collectSalary(in: state, playerID: ana, amount: 100)
        result = try GameRules.collectSalary(in: result, playerID: ana, amount: 100)

        XCTAssertEqual(result.players[0].creditHistory.missedPayments, 2)
        XCTAssertEqual(result.players[0].creditCardLoans.first?.remainingDebt, 800)
        XCTAssertEqual(try GameRules.availableCredit(for: ana, in: result), 0)
        XCTAssertThrowsError(try GameRules.borrowOnCreditCard(in: result, playerID: ana, amount: 1, installments: 1)) { error in
            XCTAssertEqual(error as? GameRuleError, .creditCut)
        }

        let (paidOff, paidOffAna) = makeState(history: CreditHistory(paidOffLoans: 3, missedPayments: 2))
        XCTAssertThrowsError(try GameRules.borrowOnCreditCard(in: paidOff, playerID: paidOffAna, amount: 1, installments: 1)) { error in
            XCTAssertEqual(error as? GameRuleError, .creditCut)
        }
    }

    func testBankruptcyIsNotAMissedPayment() throws {
        let (state, ana) = makeState(loans: [loan(debt: 500)])

        let result = try GameRules.declareBankruptcy(in: state, playerID: ana, creditor: .bank)

        XCTAssertEqual(result.players[0].creditHistory, CreditHistory())
    }

    // MARK: Saves and messages

    func testPlayerSavedWithoutCreditHistoryStartsFresh() throws {
        let json = #"{"id":"\#(UUID().uuidString)","name":"Ana","balance":100,"propertyIDs":[],"status":"active","creditCardLoans":[]}"#

        let player = try JSONDecoder().decode(Player.self, from: Data(json.utf8))

        XCTAssertEqual(player.creditHistory, CreditHistory())
    }

    func testNewErrorsRoundTripThroughJSON() throws {
        for error in [GameRuleError.creditCut, .creditCardLoanLimitReached(2)] {
            XCTAssertEqual(try JSONDecoder().decode(GameRuleError.self, from: JSONEncoder().encode(error)), error)
        }
    }
}
