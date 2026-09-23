import XCTest
@testable import Monopoly

/// Deterministic generator so role assignment and shuffles can be tested.
private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}

final class MonopolifeRulesTests: XCTestCase {
    // MARK: Helpers

    private func makeState(
        roles: [LifeRole],
        balance: Int = 1500,
        properties: [Property] = [],
        roundLimit: Int = 15
    ) -> (state: GameState, ids: [UUID]) {
        let players = roles.indices.map { Player(name: "P\($0)", balance: balance) }
        var profiles: [UUID: LifeProfile] = [:]
        for (player, role) in zip(players, roles) {
            profiles[player.id] = LifeProfile(role: role, hasAcknowledgedRole: true)
        }
        let state = GameState(
            players: players,
            properties: properties,
            currentPlayerID: players.first?.id,
            activeHouseRules: [.creditCards],
            mode: .monopolife,
            monopolife: MonopolifeState(
                roundLimit: roundLimit,
                profiles: profiles,
                lifeDeck: LifeCards.all.map(\.id)
            )
        )
        return (state, players.map(\.id))
    }

    private func happiness(_ playerID: UUID, in state: GameState) -> Int {
        state.monopolife?.profiles[playerID]?.happiness ?? -1
    }

    private func property(
        _ name: String = "Calle",
        group: ColorGroup = .brown,
        rent: Int = 10,
        owner: UUID? = nil,
        price: Int = 100
    ) -> Property {
        Property(
            name: name,
            colorGroup: group,
            purchasePrice: price,
            mortgageValue: price / 2,
            baseRent: rent,
            rentByConstructionLevel: [rent, rent * 5, rent * 15, rent * 35, rent * 50, rent * 70],
            ownerID: owner
        )
    }

    private func drawing(_ cardID: String, in state: GameState) -> GameState {
        var updated = state
        updated.monopolife?.lifeDeck = [cardID]
        return updated
    }

    private func draw(_ cardID: String, by playerID: UUID, in state: GameState) throws -> GameState {
        var generator = SeededGenerator(state: 1)
        var turnState = drawing(cardID, in: state)
        turnState.currentPlayerID = playerID
        return try GameRules.drawLifeCard(in: turnState, playerID: playerID, using: &generator)
    }

    /// Ends every player's turn once, closing the current round.
    private func finishRound(_ state: GameState) throws -> GameState {
        var updated = state
        for _ in state.players {
            guard let current = updated.currentPlayerID else { break }
            updated = try GameRules.endTurn(in: updated, playerID: current)
        }
        return updated
    }

    // MARK: Mode and setup

    func testSavedGameWithoutModeDecodesAsClassic() throws {
        let classic = GameState(players: [Player(name: "Ana", balance: 100)], properties: [])
        let data = try JSONEncoder().encode(classic)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "mode")
        json.removeValue(forKey: "monopolife")
        let legacyData = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(GameState.self, from: legacyData)

        XCTAssertEqual(decoded.mode, .classic)
        XCTAssertNil(decoded.monopolife)
    }

    func testMonopolifeStateRoundTripsThroughJSON() throws {
        var (state, ids) = makeState(roles: [.consumer, .saver])
        GameRules.adjustHappiness(of: ids[0], by: 3, reason: .lifeCard("perfect-day"), in: &state)
        state.monopolife?.profiles[ids[1]]?.possessions = [.car]

        let decoded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))

        XCTAssertEqual(decoded, state)
    }

    func testAssignRolesDoesNotRepeatWithSixPlayers() {
        var generator = SeededGenerator(state: 42)
        let ids = (0..<6).map { _ in UUID() }

        let roles = GameRules.assignRoles(to: ids, using: &generator)

        XCTAssertEqual(Set(roles.values), Set(LifeRole.allCases))
    }

    func testAssignRolesWithEightPlayersUsesEveryRoleAndRepeatsOnlyTwo() {
        var generator = SeededGenerator(state: 7)
        let ids = (0..<8).map { _ in UUID() }

        let roles = GameRules.assignRoles(to: ids, using: &generator)
        let counts = Dictionary(grouping: roles.values, by: { $0 }).mapValues(\.count)

        XCTAssertEqual(Set(roles.values), Set(LifeRole.allCases))
        XCTAssertEqual(counts.values.filter { $0 == 2 }.count, 2)
        XCTAssertTrue(counts.values.allSatisfy { $0 <= 2 })
    }

    func testAssignRolesIsDeterministicWithASeededGenerator() {
        let ids = (0..<5).map { _ in UUID() }
        var first = SeededGenerator(state: 99)
        var second = SeededGenerator(state: 99)

        XCTAssertEqual(
            GameRules.assignRoles(to: ids, using: &first),
            GameRules.assignRoles(to: ids, using: &second)
        )
    }

    func testLobbyMakesMonopolifeStateWithUnacknowledgedRoles() {
        let lobby = Lobby(
            players: [LobbyPlayer(name: "Ana", isHostControlled: true), LobbyPlayer(name: "Luis", isHostControlled: false)],
            gameMode: .monopolife,
            roundLimit: 10
        )
        var generator = SeededGenerator(state: 3)

        let state = lobby.makeGameState(initialBalance: 1500, properties: [], using: &generator)

        XCTAssertEqual(state.mode, .monopolife)
        XCTAssertEqual(state.monopolife?.roundLimit, 10)
        XCTAssertEqual(state.monopolife?.profiles.count, 2)
        XCTAssertEqual(state.monopolife?.lifeDeck.count, LifeCards.all.count)
        XCTAssertTrue(state.monopolife?.profiles.values.allSatisfy { !$0.hasAcknowledgedRole && $0.happiness == 0 } ?? false)
    }

    func testClassicLobbyHasNoMonopolifeState() {
        let lobby = Lobby(players: [LobbyPlayer(name: "Ana", isHostControlled: true)])

        let state = lobby.makeGameState(initialBalance: 1500, properties: [])

        XCTAssertEqual(state.mode, .classic)
        XCTAssertNil(state.monopolife)
    }

    func testAcknowledgeRole() throws {
        var (state, ids) = makeState(roles: [.consumer])
        state.monopolife?.profiles[ids[0]]?.hasAcknowledgedRole = false

        let result = try GameRules.acknowledgeRole(in: state, playerID: ids[0])

        XCTAssertEqual(result.monopolife?.profiles[ids[0]]?.hasAcknowledgedRole, true)
    }

    // MARK: Happiness

    func testAdjustHappinessNeverGoesBelowZeroAndLogsTheAppliedDelta() {
        var (state, ids) = makeState(roles: [.consumer])
        GameRules.adjustHappiness(of: ids[0], by: 1, reason: .bankruptcy, in: &state)

        GameRules.adjustHappiness(of: ids[0], by: -3, reason: .lifeCard("sick"), in: &state)

        XCTAssertEqual(happiness(ids[0], in: state), 0)
        XCTAssertEqual(state.monopolife?.happinessLog.map(\.delta), [1, -1])
    }

    func testAdjustHappinessDoesNothingInClassic() {
        let player = Player(name: "Ana", balance: 100)
        var state = GameState(players: [player], properties: [])

        GameRules.adjustHappiness(of: player.id, by: 5, reason: .bankruptcy, in: &state)

        XCTAssertNil(state.monopolife)
    }

    // MARK: End of the game

    func testGameFinishesWhenTheLastRoundEnds() throws {
        let (state, _) = makeState(roles: [.globetrotter, .globetrotter], roundLimit: 2)

        let afterFirstRound = try finishRound(state)
        XCTAssertEqual(afterFirstRound.round, 2)
        XCTAssertEqual(afterFirstRound.monopolife?.isFinished, false)

        let finished = try finishRound(afterFirstRound)
        XCTAssertEqual(finished.monopolife?.isFinished, true)
        XCTAssertNil(finished.currentPlayerID)
        XCTAssertEqual(finished.round, 2)
        XCTAssertThrowsError(try GameRules.requireGameNotFinished(in: finished)) { error in
            XCTAssertEqual(error as? GameRuleError, .gameFinished)
        }
    }

    func testClassicGameNeverFinishesByRounds() throws {
        let players = [Player(name: "A", balance: 0), Player(name: "B", balance: 0)]
        var state = GameState(players: players, properties: [], currentPlayerID: players[0].id)

        for _ in 0..<60 {
            state = GameRules.advanceTurn(in: state)
        }

        XCTAssertEqual(state.round, 31)
        XCTAssertNotNil(state.currentPlayerID)
        XCTAssertNoThrow(try GameRules.requireGameNotFinished(in: state))
    }

    func testWinnerIsTheHappiestAndTiesBreakOnNetWorth() {
        var (state, ids) = makeState(roles: [.consumer, .saver, .social])
        GameRules.adjustHappiness(of: ids[0], by: 10, reason: .bankruptcy, in: &state)
        GameRules.adjustHappiness(of: ids[1], by: 10, reason: .bankruptcy, in: &state)
        GameRules.adjustHappiness(of: ids[2], by: 4, reason: .bankruptcy, in: &state)
        state.players[1].balance = 2000

        XCTAssertEqual(GameRules.winners(in: state), [ids[1]])
    }

    func testFullTieIsShared() {
        var (state, ids) = makeState(roles: [.consumer, .saver])
        GameRules.adjustHappiness(of: ids[0], by: 5, reason: .bankruptcy, in: &state)
        GameRules.adjustHappiness(of: ids[1], by: 5, reason: .bankruptcy, in: &state)

        XCTAssertEqual(Set(GameRules.winners(in: state)), Set(ids))
    }

    // MARK: Consumer

    func testConsumerGainsOnePointPerFiftyOfRentCappedAtSix() throws {
        var (state, ids) = makeState(roles: [.consumer, .globetrotter])
        state.properties = [property(rent: 400, owner: ids[1]), property("Otra", group: .pink, rent: 120, owner: ids[1])]

        let expensive = try GameRules.collectRent(in: state, from: ids[0], propertyID: state.properties[0].id).state
        XCTAssertEqual(happiness(ids[0], in: expensive), 6)

        let cheap = try GameRules.collectRent(in: expensive, from: ids[0], propertyID: state.properties[1].id).state
        XCTAssertEqual(happiness(ids[0], in: cheap), 8)
    }

    func testConsumerLikesLevelingUp() throws {
        var (state, ids) = makeState(roles: [.consumer])
        state.properties = [property("A", owner: ids[0]), property("B", owner: ids[0])]

        let result = try GameRules.levelUp(in: state, propertyID: state.properties[0].id, playerID: ids[0])

        XCTAssertEqual(happiness(ids[0], in: result), LifeRoleValues.consumerLevelUp)
    }

    func testConsumerDislikesEndingARoundWithTooMuchCash() throws {
        var (state, ids) = makeState(roles: [.consumer], balance: 1501)
        GameRules.adjustHappiness(of: ids[0], by: 5, reason: .bankruptcy, in: &state)

        let result = try finishRound(state)

        XCTAssertEqual(happiness(ids[0], in: result), 3)
    }

    // MARK: Entrepreneur

    func testEntrepreneurLikesReceivingRent() throws {
        var (state, ids) = makeState(roles: [.entrepreneur, .globetrotter])
        state.properties = [property(owner: ids[0])]

        let result = try GameRules.collectRent(in: state, from: ids[1], propertyID: state.properties[0].id).state

        XCTAssertEqual(happiness(ids[0], in: result), 2)
    }

    func testEntrepreneurGainsPerHeldPropertyAtRoundEndCappedAtFive() throws {
        var (state, ids) = makeState(roles: [.entrepreneur])
        state.properties = ColorGroup.allCases.map { property($0.rawValue, group: $0, owner: ids[0]) }

        let result = try finishRound(state)

        XCTAssertEqual(happiness(ids[0], in: result), 5)
    }

    func testEntrepreneurDislikesMortgaging() throws {
        var (state, ids) = makeState(roles: [.entrepreneur])
        state.properties = [property(owner: ids[0])]
        GameRules.adjustHappiness(of: ids[0], by: 10, reason: .bankruptcy, in: &state)

        let result = try GameRules.mortgageProperty(in: state, propertyID: state.properties[0].id, playerID: ids[0])

        XCTAssertEqual(happiness(ids[0], in: result), 7)
    }

    // MARK: Saver

    func testSaverGainsPerFourHundredOfCashAtRoundEndCappedAtFive() throws {
        let (state, ids) = makeState(roles: [.saver], balance: 1500)
        XCTAssertEqual(happiness(ids[0], in: try finishRound(state)), 3)

        let (rich, richIDs) = makeState(roles: [.saver], balance: 5000)
        XCTAssertEqual(happiness(richIDs[0], in: try finishRound(rich)), 5)
    }

    func testSaverLikesSalaryOnlyWithoutCardDebt() throws {
        let (state, ids) = makeState(roles: [.saver])
        let debtFree = try GameRules.collectSalary(in: state, playerID: ids[0], amount: 200)
        XCTAssertEqual(happiness(ids[0], in: debtFree), 1)

        var indebted = state
        indebted.players[0].creditCardLoans = [CreditCardLoan(remainingDebt: 100, installmentsRemaining: 5, postponementsRemaining: 0)]
        let withDebt = try GameRules.collectSalary(in: indebted, playerID: ids[0], amount: 200)
        XCTAssertEqual(happiness(ids[0], in: withDebt), 0)
    }

    func testSaverDislikesLoans() throws {
        var (state, ids) = makeState(roles: [.saver])
        GameRules.adjustHappiness(of: ids[0], by: 10, reason: .bankruptcy, in: &state)

        let result = try GameRules.borrowOnCreditCard(in: state, playerID: ids[0], amount: 100, installments: 1)

        XCTAssertEqual(happiness(ids[0], in: result), 6)
    }

    // MARK: Social

    private func settleMoneyDeal(_ amount: Int, from payer: UUID, to recipient: UUID, in state: GameState) throws -> GameState {
        let deal = MarketDeal(
            proposerID: payer,
            transfers: [DealTransfer(from: .player(payer), to: .player(recipient), asset: .money(amount))]
        )
        let proposed = try GameRules.proposeDeal(in: state, deal: deal, proposerID: payer)
        return try GameRules.acceptDeal(in: proposed, dealID: deal.id, playerID: recipient)
    }

    func testSocialScoresAtMostTwoDealsPerRound() throws {
        let (state, ids) = makeState(roles: [.social, .saver])
        var result = state
        for _ in 0..<3 {
            result = try settleMoneyDeal(100, from: ids[0], to: ids[1], in: result)
        }

        XCTAssertEqual(happiness(ids[0], in: result), 6)
        XCTAssertEqual(happiness(ids[1], in: result), 0)
    }

    func testSocialIgnoresTinyDeals() throws {
        let (state, ids) = makeState(roles: [.social, .saver])

        let result = try settleMoneyDeal(10, from: ids[0], to: ids[1], in: state)

        XCTAssertEqual(happiness(ids[0], in: result), 0)
        XCTAssertEqual(result.monopolife?.profiles[ids[0]]?.tookPartInDealThisRound, true)
    }

    func testDealWithSharesIsScorableWhateverTheMoney() throws {
        var (state, ids) = makeState(roles: [.social, .saver])
        state.properties = [property(owner: ids[1])]
        let deal = MarketDeal(
            proposerID: ids[0],
            transfers: [
                DealTransfer(from: .player(ids[1]), to: .player(ids[0]), asset: .shares(propertyID: state.properties[0].id, count: 1)),
                DealTransfer(from: .player(ids[0]), to: .player(ids[1]), asset: .money(1))
            ]
        )

        let proposed = try GameRules.proposeDeal(in: state, deal: deal, proposerID: ids[0])
        let result = try GameRules.acceptDeal(in: proposed, dealID: deal.id, playerID: ids[1])

        XCTAssertEqual(happiness(ids[0], in: result), 3)
    }

    func testSocialDislikesARoundWithoutDealsAndCountersReset() throws {
        var (state, ids) = makeState(roles: [.social, .saver], balance: 0)
        GameRules.adjustHappiness(of: ids[0], by: 5, reason: .bankruptcy, in: &state)
        state.players[1].balance = 500
        let traded = try settleMoneyDeal(100, from: ids[1], to: ids[0], in: state)

        let afterTradingRound = try finishRound(traded)
        XCTAssertEqual(happiness(ids[0], in: afterTradingRound), 8)
        XCTAssertEqual(afterTradingRound.monopolife?.profiles[ids[0]]?.scoredDealsThisRound, 0)
        XCTAssertEqual(afterTradingRound.monopolife?.profiles[ids[0]]?.tookPartInDealThisRound, false)

        let afterQuietRound = try finishRound(afterTradingRound)
        XCTAssertEqual(happiness(ids[0], in: afterQuietRound), 7)
    }

    // MARK: Investor

    func testInvestorLikesCreatingAndCollectingInvestments() throws {
        var (state, ids) = makeState(roles: [.investor, .saver, .globetrotter])
        state.properties = [property(rent: 100, owner: ids[1])]
        let investment = RentInvestment(investorID: ids[0], recipientID: ids[1], propertyID: state.properties[0].id, percentage: 50)
        let deal = MarketDeal(
            proposerID: ids[0],
            transfers: [DealTransfer(from: .player(ids[0]), to: .player(ids[1]), asset: .money(100))],
            proposedInvestment: investment
        )
        let proposed = try GameRules.proposeDeal(in: state, deal: deal, proposerID: ids[0])
        let invested = try GameRules.acceptDeal(in: proposed, dealID: deal.id, playerID: ids[1])
        XCTAssertEqual(happiness(ids[0], in: invested), 3)

        let paid = try GameRules.collectRent(in: invested, from: ids[2], propertyID: state.properties[0].id).state
        XCTAssertEqual(happiness(ids[0], in: paid), 4)
    }

    func testInvestorGainsPerColorGroupAtRoundEndCappedAtFour() throws {
        var (state, ids) = makeState(roles: [.investor], balance: 0)
        state.properties = ColorGroup.allCases.map { property($0.rawValue, group: $0, owner: ids[0]) }

        XCTAssertEqual(happiness(ids[0], in: try finishRound(state)), 4)
    }

    func testInvestorDislikesTaxes() throws {
        var (state, ids) = makeState(roles: [.investor])
        GameRules.adjustHappiness(of: ids[0], by: 5, reason: .bankruptcy, in: &state)

        XCTAssertEqual(happiness(ids[0], in: try GameRules.payTax(in: state, playerID: ids[0], amount: 100)), 3)
        XCTAssertEqual(happiness(ids[0], in: try GameRules.payTax(in: state, playerID: ids[0], amount: 0)), 5)
    }

    // MARK: Globetrotter

    func testGlobetrotterLikesPassingGo() throws {
        let (state, ids) = makeState(roles: [.globetrotter])

        XCTAssertEqual(happiness(ids[0], in: try GameRules.collectSalary(in: state, playerID: ids[0], amount: 200)), 2)
    }

    func testGlobetrotterStampsEachColorOnceAndGetsTheFullPassportBonus() throws {
        var (state, ids) = makeState(roles: [.globetrotter, .saver], balance: 10_000)
        state.properties = ColorGroup.allCases.map { property($0.rawValue, group: $0, rent: 1, owner: ids[1]) }

        var result = try GameRules.collectRent(in: state, from: ids[0], propertyID: state.properties[0].id).state
        result = try GameRules.collectRent(in: result, from: ids[0], propertyID: state.properties[0].id).state
        XCTAssertEqual(happiness(ids[0], in: result), 3)

        for property in state.properties.dropFirst() {
            result = try GameRules.collectRent(in: result, from: ids[0], propertyID: property.id).state
        }
        XCTAssertEqual(happiness(ids[0], in: result), 8 * 3 + 8)
    }

    func testGlobetrotterDislikesBuyingFromTheBank() throws {
        var (state, ids) = makeState(roles: [.globetrotter, .globetrotter])
        state.properties = [property(), property("B")]
        GameRules.adjustHappiness(of: ids[0], by: 5, reason: .bankruptcy, in: &state)
        GameRules.adjustHappiness(of: ids[1], by: 5, reason: .bankruptcy, in: &state)

        let bought = try GameRules.buyProperty(in: state, playerID: ids[0], propertyID: state.properties[0].id)
        XCTAssertEqual(happiness(ids[0], in: bought), 3)

        let auctioned = try GameRules.resolveAuction(
            in: bought,
            propertyID: state.properties[1].id,
            bids: [AuctionBid(playerID: ids[1], amount: 50)]
        )
        XCTAssertEqual(happiness(ids[1], in: auctioned), 3)
    }

    func testSharedPurchaseCountsForEachBuyer() throws {
        var (state, ids) = makeState(roles: [.globetrotter, .globetrotter])
        state.properties = [property()]
        GameRules.adjustHappiness(of: ids[0], by: 5, reason: .bankruptcy, in: &state)
        GameRules.adjustHappiness(of: ids[1], by: 5, reason: .bankruptcy, in: &state)
        let deal = MarketDeal(
            proposerID: ids[0],
            sharedPurchase: SharedPurchase(
                propertyID: state.properties[0].id,
                buyers: [PropertyShare(playerID: ids[0], shares: 5), PropertyShare(playerID: ids[1], shares: 5)]
            )
        )

        let proposed = try GameRules.proposeDeal(in: state, deal: deal, proposerID: ids[0])
        let result = try GameRules.acceptDeal(in: proposed, dealID: deal.id, playerID: ids[1])

        XCTAssertEqual(happiness(ids[0], in: result), 3)
        XCTAssertEqual(happiness(ids[1], in: result), 3)
    }

    // MARK: Roles only react to their own likes

    func testEventsDoNotAffectOtherRoles() throws {
        var (state, ids) = makeState(roles: [.saver, .consumer])
        state.properties = [property(rent: 300, owner: ids[1])]

        let rent = try GameRules.collectRent(in: state, from: ids[0], propertyID: state.properties[0].id).state
        let salary = try GameRules.collectSalary(in: rent, playerID: ids[1], amount: 200)
        let tax = try GameRules.payTax(in: salary, playerID: ids[1], amount: 50)

        XCTAssertEqual(happiness(ids[0], in: tax), 0)
        XCTAssertEqual(happiness(ids[1], in: tax), 0)
        XCTAssertEqual(tax.monopolife?.happinessLog, [])
    }

    func testClassicGamesNeverTrackHappiness() throws {
        let players = [Player(name: "A", balance: 1000), Player(name: "B", balance: 1000)]
        var state = GameState(players: players, properties: [property(rent: 400, owner: players[1].id)])
        state = try GameRules.collectRent(in: state, from: players[0].id, propertyID: state.properties[0].id).state
        state = try GameRules.collectSalary(in: state, playerID: players[0].id, amount: 200)

        XCTAssertNil(state.monopolife)
    }

    // MARK: Bankruptcy

    func testMonopolifeBankruptcyHalvesHappinessAndKeepsThePlayerIn() throws {
        var (state, ids) = makeState(roles: [.globetrotter, .saver], balance: 30)
        state.properties = [property(owner: ids[0])]
        GameRules.adjustHappiness(of: ids[0], by: 7, reason: .lifeCard("perfect-day"), in: &state)
        state.monopolife?.profiles[ids[0]]?.rentStamps = [.pink]
        state.players[0].creditCardLoans = [CreditCardLoan(remainingDebt: 100, installmentsRemaining: 2, postponementsRemaining: 0)]

        let result = try GameRules.declareBankruptcy(in: state, playerID: ids[0], creditor: .player(ids[1]))

        XCTAssertEqual(result.players[0].status, .active)
        XCTAssertEqual(result.players[0].balance, LifeRoleValues.bankruptcyRescueBalance)
        XCTAssertEqual(result.players[0].creditCardLoans, [])
        XCTAssertEqual(result.players[1].balance, 60)
        XCTAssertEqual(result.properties[0].ownerID, ids[1])
        XCTAssertEqual(happiness(ids[0], in: result), 3)
        XCTAssertEqual(result.monopolife?.profiles[ids[0]]?.rentStamps, [.pink])
        XCTAssertEqual(result.monopolife?.happinessLog.last?.reason, .bankruptcy)
        XCTAssertEqual(result.currentPlayerID, ids[0])
    }

    // MARK: Life Cards: data

    func testDeckHasThirtyCardsWithHappinessForEveryRole() {
        XCTAssertEqual(LifeCards.all.count, 30)
        XCTAssertEqual(Set(LifeCards.all.map(\.id)).count, 30)
        for card in LifeCards.all {
            XCTAssertEqual(Set(card.happiness.keys), Set(LifeRole.allCases), card.id)
        }
    }

    /// MONOPOLIFE_RULES 3.2: what each role can get from the whole deck (decisions
    /// only count when positive, since they can be passed) stays within ±2.
    func testDeckIsBalancedAcrossRoles() {
        let totals = LifeRole.allCases.map { role in
            LifeCards.all.reduce(0) { total, card in
                let value = card.happiness(for: role)
                return total + (card.kind == .decision ? max(0, value) : value)
            }
        }
        XCTAssertLessThanOrEqual(totals.max()! - totals.min()!, 2, "Totals by role: \(totals)")
    }

    func testDeckHasBadLuckCards() {
        let badForEveryone = LifeCards.all.filter { card in LifeRole.allCases.allSatisfy { card.happiness(for: $0) <= 0 } }
        XCTAssertGreaterThanOrEqual(badForEveryone.count, 8)
    }

    // MARK: Life Cards: drawing

    func testShuffleIsDeterministicWithASeededGenerator() {
        var first = SeededGenerator(state: 5)
        var second = SeededGenerator(state: 5)

        XCTAssertEqual(GameRules.shuffledLifeDeck(using: &first), GameRules.shuffledLifeDeck(using: &second))
    }

    func testDrawingTheWholeDeckGivesEachCardOnceThenReshuffles() throws {
        var (state, ids) = makeState(roles: [.saver], balance: 100_000)
        var generator = SeededGenerator(state: 11)
        state.monopolife?.lifeDeck = GameRules.shuffledLifeDeck(using: &generator)
        var drawn: [String] = []

        for _ in 0..<31 {
            state = try GameRules.drawLifeCard(in: state, playerID: ids[0], using: &generator)
            drawn.append(state.monopolife!.lastLifeCardDraw!.cardID)
            if state.monopolife?.pendingLifeCard != nil {
                state = try GameRules.resolveLifeCardDecision(in: state, playerID: ids[0], accept: false)
            }
        }

        XCTAssertEqual(Set(drawn.prefix(30)), Set(LifeCards.all.map(\.id)))
        XCTAssertEqual(state.monopolife?.lifeDeck.count, 29)
        XCTAssertEqual(state.monopolife?.lastLifeCardDraw?.sequence, 31)
    }

    func testSameCardAffectsRolesDifferently() throws {
        let (state, ids) = makeState(roles: [.consumer, .saver, .social])

        var consumer = try draw("buy-car", by: ids[0], in: state)
        consumer = try GameRules.resolveLifeCardDecision(in: consumer, playerID: ids[0], accept: true)
        XCTAssertEqual(happiness(ids[0], in: consumer), 7)

        var saver = drawing("buy-car", in: state)
        saver.currentPlayerID = ids[1]
        GameRules.adjustHappiness(of: ids[1], by: 5, reason: .bankruptcy, in: &saver)
        saver = try draw("buy-car", by: ids[1], in: saver)
        saver = try GameRules.resolveLifeCardDecision(in: saver, playerID: ids[1], accept: true)
        XCTAssertEqual(happiness(ids[1], in: saver), 3)

        var social = state
        GameRules.adjustHappiness(of: ids[2], by: 10, reason: .bankruptcy, in: &social)
        GameRules.adjustHappiness(of: ids[0], by: 10, reason: .bankruptcy, in: &social)
        let fightSocial = try draw("friend-fight", by: ids[2], in: social)
        let fightConsumer = try draw("friend-fight", by: ids[0], in: social)
        XCTAssertEqual(happiness(ids[2], in: fightSocial), 5)
        XCTAssertEqual(happiness(ids[0], in: fightConsumer), 9)
    }

    func testEventCardMovesMoneyAndHappiness() throws {
        let (state, ids) = makeState(roles: [.saver])

        let result = try draw("year-end-bonus", by: ids[0], in: state)

        XCTAssertEqual(result.players[0].balance, 1650)
        XCTAssertEqual(happiness(ids[0], in: result), 6)
    }

    func testDividendsAreCapped() throws {
        var (state, ids) = makeState(roles: [.investor], balance: 0)
        state.properties = (0..<12).map { property("P\($0)", owner: ids[0]) }

        let result = try draw("dividends", by: ids[0], in: state)

        XCTAssertEqual(result.players[0].balance, 200)
    }

    func testBirthdayCollectsWhatEachPlayerCanPay() throws {
        var (state, ids) = makeState(roles: [.social, .saver, .saver])
        state.players[2].balance = 5

        let result = try draw("birthday", by: ids[0], in: state)

        XCTAssertEqual(result.players[0].balance, 1525)
        XCTAssertEqual(result.players[1].balance, 1480)
        XCTAssertEqual(result.players[2].balance, 0)
    }

    func testPartyGivesEveryOtherPlayerAPoint() throws {
        let (state, ids) = makeState(roles: [.social, .saver, .investor])

        var result = try draw("party", by: ids[0], in: state)
        result = try GameRules.resolveLifeCardDecision(in: result, playerID: ids[0], accept: true)

        XCTAssertEqual(happiness(ids[0], in: result), 7)
        XCTAssertEqual(happiness(ids[1], in: result), 1)
        XCTAssertEqual(happiness(ids[2], in: result), 1)
        XCTAssertEqual(result.players[0].balance, 1350)
    }

    func testMovementCardAppliesHappiness() throws {
        let (state, ids) = makeState(roles: [.globetrotter])

        let result = try draw("backpacking", by: ids[0], in: state)

        XCTAssertEqual(happiness(ids[0], in: result), 7)
        XCTAssertEqual(result.players[0].balance, 1500)
    }

    func testPaymentsNeverGoBelowZero() throws {
        let (state, ids) = makeState(roles: [.saver], balance: 40)

        let result = try draw("sick", by: ids[0], in: state)

        XCTAssertEqual(result.players[0].balance, 0)
    }

    // MARK: Life Cards: possessions

    func testPossessionsAreGainedUsedAndLost() throws {
        var (state, ids) = makeState(roles: [.globetrotter])
        state = try draw("buy-car", by: ids[0], in: state)
        state = try GameRules.resolveLifeCardDecision(in: state, playerID: ids[0], accept: true)
        XCTAssertEqual(state.monopolife?.profiles[ids[0]]?.possessions, [.car])
        XCTAssertEqual(state.players[0].balance, 1200)
        XCTAssertEqual(happiness(ids[0], in: state), 6)

        state = try draw("car-breaks", by: ids[0], in: state)
        XCTAssertEqual(state.players[0].balance, 1050)
        XCTAssertEqual(happiness(ids[0], in: state), 1)
        XCTAssertEqual(state.monopolife?.lastLifeCardDraw?.hadEffect, true)

        state = try draw("buy-car", by: ids[0], in: state)
        state = try GameRules.resolveLifeCardDecision(in: state, playerID: ids[0], accept: true)
        XCTAssertEqual(state.monopolife?.profiles[ids[0]]?.possessions, [.car])
    }

    func testPossessionCardDoesNothingWithoutThePossession() throws {
        let (state, ids) = makeState(roles: [.globetrotter])

        let result = try draw("car-breaks", by: ids[0], in: state)

        XCTAssertEqual(result.players[0].balance, 1500)
        XCTAssertEqual(happiness(ids[0], in: result), 0)
        XCTAssertEqual(result.monopolife?.lastLifeCardDraw?.hadEffect, false)
    }

    func testStolenTelevisionIsRemoved() throws {
        var (state, ids) = makeState(roles: [.consumer])
        state.monopolife?.profiles[ids[0]]?.possessions = [.television, .car]
        GameRules.adjustHappiness(of: ids[0], by: 10, reason: .bankruptcy, in: &state)

        let result = try draw("tv-stolen", by: ids[0], in: state)

        XCTAssertEqual(result.monopolife?.profiles[ids[0]]?.possessions, [.car])
        XCTAssertEqual(happiness(ids[0], in: result), 5)
    }

    // MARK: Life Cards: decisions

    func testDecisionBlocksDrawingAndEndingTheTurnUntilResolved() throws {
        let (state, ids) = makeState(roles: [.consumer, .saver])
        let pending = try draw("big-tv", by: ids[0], in: state)
        XCTAssertEqual(pending.monopolife?.pendingLifeCard?.cardID, "big-tv")
        XCTAssertEqual(pending.players[0].balance, 1500)

        var generator = SeededGenerator(state: 2)
        XCTAssertThrowsError(try GameRules.drawLifeCard(in: pending, playerID: ids[0], using: &generator)) { error in
            XCTAssertEqual(error as? GameRuleError, .lifeCardDecisionPending)
        }
        XCTAssertThrowsError(try GameRules.endTurn(in: pending, playerID: ids[0])) { error in
            XCTAssertEqual(error as? GameRuleError, .lifeCardDecisionPending)
        }

        let passed = try GameRules.resolveLifeCardDecision(in: pending, playerID: ids[0], accept: false)
        XCTAssertNil(passed.monopolife?.pendingLifeCard)
        XCTAssertEqual(passed.players, state.players)
        XCTAssertEqual(happiness(ids[0], in: passed), 0)
        XCTAssertNoThrow(try GameRules.endTurn(in: passed, playerID: ids[0]))
    }

    func testAcceptingWithoutEnoughMoneyFails() throws {
        let (state, ids) = makeState(roles: [.consumer], balance: 100)
        let pending = try draw("buy-car", by: ids[0], in: state)

        XCTAssertThrowsError(try GameRules.resolveLifeCardDecision(in: pending, playerID: ids[0], accept: true)) { error in
            XCTAssertEqual(error as? GameRuleError, .insufficientFunds(playerID: ids[0], required: 300, available: 100))
        }
    }

    func testAcceptingAppliesNegativeHappinessToo() throws {
        var (state, ids) = makeState(roles: [.saver])
        GameRules.adjustHappiness(of: ids[0], by: 5, reason: .bankruptcy, in: &state)

        var result = try draw("beach-vacation", by: ids[0], in: state)
        result = try GameRules.resolveLifeCardDecision(in: result, playerID: ids[0], accept: true)

        XCTAssertEqual(happiness(ids[0], in: result), 3)
        XCTAssertEqual(result.players[0].balance, 1250)
    }

    func testOnlyTheDrawerCanResolveTheDecision() throws {
        let (state, ids) = makeState(roles: [.consumer, .saver])
        let pending = try draw("big-tv", by: ids[0], in: state)

        XCTAssertThrowsError(try GameRules.resolveLifeCardDecision(in: pending, playerID: ids[1], accept: true)) { error in
            XCTAssertEqual(error as? GameRuleError, .noPendingLifeCard)
        }
    }

    func testDrawingOutOfTurnFails() {
        let (state, ids) = makeState(roles: [.consumer, .saver])
        var generator = SeededGenerator(state: 1)

        XCTAssertThrowsError(try GameRules.drawLifeCard(in: state, playerID: ids[1], using: &generator)) { error in
            XCTAssertEqual(error as? GameRuleError, .notPlayersTurn(currentPlayerID: ids[0]))
        }
    }

    func testLifeCardsAreRejectedInClassic() {
        let player = Player(name: "Ana", balance: 100)
        let state = GameState(players: [player], properties: [], currentPlayerID: player.id)
        var generator = SeededGenerator(state: 1)

        XCTAssertThrowsError(try GameRules.drawLifeCard(in: state, playerID: player.id, using: &generator)) { error in
            XCTAssertEqual(error as? GameRuleError, .monopolifeOnly)
        }
        XCTAssertThrowsError(try GameRules.resolveLifeCardDecision(in: state, playerID: player.id, accept: true)) { error in
            XCTAssertEqual(error as? GameRuleError, .monopolifeOnly)
        }
    }

    // MARK: Networking

    func testNewIntentsRoundTripThroughJSON() throws {
        let id = UUID()
        for intent in [
            GameIntent.acknowledgeRole(playerID: id),
            .drawLifeCard(playerID: id),
            .resolveLifeCardDecision(playerID: id, accept: true)
        ] {
            let decoded = try JSONDecoder().decode(GameIntent.self, from: JSONEncoder().encode(intent))
            XCTAssertEqual(decoded, intent)
        }
    }

    func testRoomInfoCarriesTheMode() throws {
        let info = DiscoveredRoom.discoveryInfo(roomID: UUID(), name: "Ana", playerCount: 2, phase: .lobby, round: 1, mode: .monopolife)
        let room = try XCTUnwrap(DiscoveredRoom(peerID: PeerID("peer"), discoveryInfo: info))

        XCTAssertEqual(room.mode, .monopolife)
    }
}
