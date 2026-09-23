import XCTest
@testable import Monopoly

final class FreeParkingTests: XCTestCase {
    private func makeState(
        balance: Int = 1500,
        rules: Set<HouseRule> = [.freeParkingJackpot, .creditCards],
        properties: [Property] = [],
        pot: Int = 0
    ) -> (state: GameState, ana: UUID, luis: UUID) {
        let ana = Player(name: "Ana", balance: balance)
        let luis = Player(name: "Luis", balance: balance)
        let state = GameState(
            players: [ana, luis],
            properties: properties,
            currentPlayerID: ana.id,
            activeHouseRules: rules,
            freeParkingPot: pot
        )
        return (state, ana.id, luis.id)
    }

    private func balance(of playerID: UUID, in state: GameState) -> Int {
        state.players.first(where: { $0.id == playerID })?.balance ?? -1
    }

    // MARK: Travel

    func testTravelFaresFollowTheBoardSides() {
        XCTAssertEqual(TravelRoute.sameSide.fare, 100)
        XCTAssertEqual(TravelRoute.nextSide.fare, 100)
        XCTAssertEqual(TravelRoute.twoSidesAhead.fare, 200)
        XCTAssertEqual(TravelRoute.threeSidesAhead.fare, 300)
        XCTAssertEqual(TravelRoute.fullLap.fare, 400)
    }

    func testPayTravelChargesTheFareAndAddsItToThePot() throws {
        let (state, ana, _) = makeState()

        let result = try GameRules.payTravel(in: state, playerID: ana, route: .threeSidesAhead)

        XCTAssertEqual(balance(of: ana, in: result), 1200)
        XCTAssertEqual(result.freeParkingPot, 300)
    }

    func testPayTravelWithoutTheHouseRuleTakesMoneyOutOfTheGame() throws {
        let (state, ana, _) = makeState(rules: [])

        let result = try GameRules.payTravel(in: state, playerID: ana, route: .fullLap)

        XCTAssertEqual(balance(of: ana, in: result), 1100)
        XCTAssertEqual(result.freeParkingPot, 0)
    }

    func testPayTravelFailsWhenBalanceIsInsufficient() {
        let (state, ana, _) = makeState(balance: 150)

        XCTAssertThrowsError(try GameRules.payTravel(in: state, playerID: ana, route: .twoSidesAhead)) { error in
            XCTAssertEqual(error as? GameRuleError, .insufficientFunds(playerID: ana, required: 200, available: 150))
        }
    }

    func testPayTravelIsNotATaxForMonopolifeRoles() throws {
        let ana = Player(name: "Ana", balance: 1500)
        let state = GameState(
            players: [ana],
            properties: [],
            currentPlayerID: ana.id,
            mode: .monopolife,
            monopolife: MonopolifeState(
                roundLimit: 15,
                profiles: [ana.id: LifeProfile(role: .investor, hasAcknowledgedRole: true)],
                lifeDeck: []
            )
        )

        let result = try GameRules.payTravel(in: state, playerID: ana.id, route: .nextSide)

        XCTAssertEqual(result.monopolife?.profiles[ana.id]?.happiness, 0)
    }

    // MARK: Pot

    func testPayTaxAddsToThePotOnlyWithTheHouseRule() throws {
        let (withRule, ana, _) = makeState()
        let (withoutRule, other, _) = makeState(rules: [])

        XCTAssertEqual(try GameRules.payTax(in: withRule, playerID: ana, amount: 200).freeParkingPot, 200)
        XCTAssertEqual(try GameRules.payTax(in: withoutRule, playerID: other, amount: 200).freeParkingPot, 0)
    }

    func testCollectFreeParkingGivesTheWholePotAndEmptiesIt() throws {
        let (state, ana, _) = makeState(pot: 650)

        let result = try GameRules.collectFreeParking(in: state, playerID: ana)

        XCTAssertEqual(balance(of: ana, in: result), 2150)
        XCTAssertEqual(result.freeParkingPot, 0)
    }

    func testCollectFreeParkingFailsWhenThePotIsEmpty() {
        let (state, ana, _) = makeState()

        XCTAssertThrowsError(try GameRules.collectFreeParking(in: state, playerID: ana)) { error in
            XCTAssertEqual(error as? GameRuleError, .freeParkingPotEmpty)
        }
    }

    func testCollectFreeParkingFailsWhenTheHouseRuleIsOff() {
        let (state, ana, _) = makeState(rules: [], pot: 100)

        XCTAssertThrowsError(try GameRules.collectFreeParking(in: state, playerID: ana)) { error in
            XCTAssertEqual(error as? GameRuleError, .freeParkingDisabled)
        }
    }

    func testTravelAndCollectFreeParkingRequireTheTurn() {
        XCTAssertTrue(GameIntent.payTravel(playerID: UUID(), route: .nextSide).requiresTurn)
        XCTAssertTrue(GameIntent.collectFreeParking(playerID: UUID()).requiresTurn)
    }

    func testUnmortgageAddsOnlyTheInterestToThePot() throws {
        let (base, ana, _) = makeState()
        let property = Property(
            name: "Calle",
            colorGroup: .brown,
            purchasePrice: 100,
            mortgageValue: 50,
            baseRent: 10,
            ownerID: ana,
            isMortgaged: true
        )
        var state = base
        state.properties = [property]

        let result = try GameRules.unmortgageProperty(in: state, propertyID: property.id, playerID: ana)

        XCTAssertEqual(balance(of: ana, in: result), 1445)
        XCTAssertEqual(result.freeParkingPot, 5)
    }

    // MARK: Credit card interest

    func testBorrowOnCreditCardRecordsTheInterestOfTheLoan() throws {
        let (state, ana, _) = makeState()

        let result = try GameRules.borrowOnCreditCard(in: state, playerID: ana, amount: 500, installments: 2)

        let loan = try XCTUnwrap(result.players[0].creditCardLoans.first)
        XCTAssertEqual(loan.remainingDebt, 550)
        XCTAssertEqual(loan.remainingInterest, 50)
        XCTAssertEqual(result.freeParkingPot, 0, "Interest reaches the pot when it is paid, not when borrowing.")
    }

    func testInstallmentsSendTheirShareOfInterestToThePot() throws {
        let (base, ana, _) = makeState()
        var state = try GameRules.borrowOnCreditCard(in: base, playerID: ana, amount: 500, installments: 2)

        state = try GameRules.collectSalary(in: state, playerID: ana, amount: 200)
        XCTAssertEqual(state.freeParkingPot, 25)

        state = try GameRules.collectSalary(in: state, playerID: ana, amount: 200)
        XCTAssertEqual(state.freeParkingPot, 50)
        XCTAssertTrue(state.players[0].creditCardLoans.isEmpty)
    }

    func testUnevenInstallmentsStillSendExactlyTheWholeInterest() throws {
        let (base, ana, _) = makeState()
        var state = try GameRules.borrowOnCreditCard(in: base, playerID: ana, amount: 700, installments: 3)

        for _ in 0..<3 {
            state = try GameRules.collectSalary(in: state, playerID: ana, amount: 200)
        }

        XCTAssertTrue(state.players[0].creditCardLoans.isEmpty)
        XCTAssertEqual(state.freeParkingPot, 70)
    }

    func testPostponedInstallmentSendsNothingToThePot() throws {
        let (base, ana, _) = makeState()
        let state = try GameRules.borrowOnCreditCard(in: base, playerID: ana, amount: 500, installments: 1)
        let loanID = try XCTUnwrap(state.players[0].creditCardLoans.first?.id)

        let result = try GameRules.collectSalary(in: state, playerID: ana, amount: 200, postponedLoanIDs: [loanID])

        XCTAssertEqual(result.freeParkingPot, 0)
    }

    func testEarlyPaymentsSendTheirShareOfInterestToThePot() throws {
        let (base, ana, _) = makeState()
        var state = try GameRules.borrowOnCreditCard(in: base, playerID: ana, amount: 1000, installments: 5)
        let loanID = try XCTUnwrap(state.players[0].creditCardLoans.first?.id)

        state = try GameRules.payCreditCard(in: state, playerID: ana, loanID: loanID, amount: 330)
        XCTAssertEqual(state.freeParkingPot, 30)

        state = try GameRules.payCreditCard(in: state, playerID: ana, loanID: loanID, amount: 770)
        XCTAssertEqual(state.freeParkingPot, 100)
    }

    func testCardInterestWithoutTheHouseRuleLeavesTheGame() throws {
        let (base, ana, _) = makeState(rules: [.creditCards])
        var state = try GameRules.borrowOnCreditCard(in: base, playerID: ana, amount: 1000, installments: 1)
        let loanID = try XCTUnwrap(state.players[0].creditCardLoans.first?.id)

        state = try GameRules.payCreditCard(in: state, playerID: ana, loanID: loanID, amount: 1100)

        XCTAssertEqual(state.freeParkingPot, 0)
    }

    func testLoanSavedBeforeInterestTrackingDecodesWithoutInterest() throws {
        let json = #"{"id":"\#(UUID().uuidString)","remainingDebt":550,"installmentsRemaining":2,"postponementsRemaining":3}"#

        let loan = try JSONDecoder().decode(CreditCardLoan.self, from: Data(json.utf8))

        XCTAssertEqual(loan.remainingDebt, 550)
        XCTAssertEqual(loan.remainingInterest, 0)
    }

    // MARK: Monopolife

    func testLifeCardPaymentsGoToThePot() throws {
        let ana = Player(name: "Ana", balance: 1500)
        let state = GameState(
            players: [ana],
            properties: [],
            currentPlayerID: ana.id,
            activeHouseRules: [.freeParkingJackpot],
            mode: .monopolife,
            monopolife: MonopolifeState(
                roundLimit: 15,
                profiles: [ana.id: LifeProfile(role: .saver, hasAcknowledgedRole: true)],
                lifeDeck: ["sick"]
            )
        )
        var generator = SystemRandomNumberGenerator()

        let result = try GameRules.drawLifeCard(in: state, playerID: ana.id, using: &generator)

        XCTAssertEqual(result.players[0].balance, 1400)
        XCTAssertEqual(result.freeParkingPot, 100)
    }

    // MARK: Setup and wire format

    func testLobbyActivatesTheFreeParkingRule() {
        let lobby = Lobby(
            players: [LobbyPlayer(name: "Ana", isHostControlled: true), LobbyPlayer(name: "Luis", isHostControlled: false)],
            creditCardsEnabled: false,
            freeParkingEnabled: true
        )

        let state = lobby.makeGameState(initialBalance: 1500, properties: [])

        XCTAssertEqual(state.activeHouseRules, [.freeParkingJackpot])
        XCTAssertEqual(state.freeParkingPot, 0)
    }

    func testNewIntentsRoundTripThroughCodable() throws {
        let intents: [GameIntent] = [
            .payTravel(playerID: UUID(), route: .fullLap),
            .collectFreeParking(playerID: UUID())
        ]

        for intent in intents {
            let data = try JSONEncoder().encode(intent)
            XCTAssertEqual(try JSONDecoder().decode(GameIntent.self, from: data), intent)
        }
    }

    func testFreeParkingErrorsRoundTripThroughCodable() throws {
        for error in [GameRuleError.freeParkingDisabled, .freeParkingPotEmpty] {
            let data = try JSONEncoder().encode(error)
            XCTAssertEqual(try JSONDecoder().decode(GameRuleError.self, from: data), error)
        }
    }

    func testGameStateSavedBeforeThePotDecodesWithAnEmptyPot() throws {
        let (state, _, _) = makeState(pot: 300)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        json.removeValue(forKey: "freeParkingPot")

        let decoded = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))

        XCTAssertEqual(decoded.freeParkingPot, 0)
    }
}
