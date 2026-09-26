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

    /// Happiness a player got for one reason, to test a like without the rent visit
    /// every rent payment also gives.
    private func happiness(_ playerID: UUID, from reason: HappinessReason, in state: GameState) -> Int {
        (state.monopolife?.happinessLog ?? [])
            .filter { $0.playerID == playerID && $0.reason == reason }
            .reduce(0) { $0 + $1.delta }
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

    func testSavedInvestorPlaysOnAsEntrepreneur() throws {
        let legacy = Data("""
        {"role": "investor", "happiness": 4}
        """.utf8)
        let profile = try JSONDecoder().decode(LifeProfile.self, from: legacy)
        XCTAssertEqual(profile.role, .entrepreneur)
        XCTAssertEqual(profile.roundsWithoutLevelUp, 0)
        XCTAssertEqual(profile.rentContactsThisRound, [])

        let effect = try JSONDecoder().decode([LifeRoleEffect].self, from: Data(#"["investorTax", "saverLoan"]"#.utf8))
        XCTAssertEqual(effect, [.entrepreneurMortgage, .saverLoan])
    }

    func testAssignRolesDoesNotRepeatWhileThereAreUnusedRoles() {
        var generator = SeededGenerator(state: 42)
        let ids = LifeRole.playable.map { _ in UUID() }

        let roles = GameRules.assignRoles(to: ids, using: &generator)

        XCTAssertEqual(Set(roles.values), Set(LifeRole.playable))
    }

    func testAssignRolesWithTwoPlayersMoreThanRolesRepeatsOnlyTwo() {
        var generator = SeededGenerator(state: 7)
        let ids = (0..<LifeRole.playable.count + 2).map { _ in UUID() }

        let roles = GameRules.assignRoles(to: ids, using: &generator)
        let counts = Dictionary(grouping: roles.values, by: { $0 }).mapValues(\.count)

        XCTAssertEqual(Set(roles.values), Set(LifeRole.playable))
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

    func testConsumerGainsOnePointPerHundredOfRentCappedAtSix() throws {
        var (state, ids) = makeState(roles: [.consumer, .globetrotter])
        state.properties = [property(rent: 700, owner: ids[1]), property("Otra", group: .pink, rent: 190, owner: ids[1])]

        let expensive = try GameRules.collectRent(in: state, from: ids[0], propertyID: state.properties[0].id).state
        XCTAssertEqual(happiness(ids[0], from: .role(.consumerRentPaid), in: expensive), 6)

        let cheap = try GameRules.collectRent(in: expensive, from: ids[0], propertyID: state.properties[1].id).state
        XCTAssertEqual(happiness(ids[0], from: .role(.consumerRentPaid), in: cheap), 7)
    }

    func testConsumerLikesLevelingUpAsAMinorityShareholder() throws {
        var (state, ids) = makeState(roles: [.consumer, .consumer])
        var street = property()
        street.ownership = [PropertyShare(playerID: ids[1], shares: 7), PropertyShare(playerID: ids[0], shares: 3)]
        state.properties = [street]

        let result = try GameRules.levelUp(in: state, propertyID: street.id, playerID: ids[0])

        XCTAssertEqual(happiness(ids[0], in: result), LifeRoleValues.consumerLevelUp)
        XCTAssertEqual(happiness(ids[1], in: result), 0)
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

    // MARK: Rent visit

    func testRentVisitPointsGrowWithSideAndLevelAndDependOnTheRole() {
        XCTAssertEqual(LifeRoleValues.rentVisitPoints(for: .consumer, boardSide: 1, level: 0), 1)
        XCTAssertEqual(LifeRoleValues.rentVisitPoints(for: .consumer, boardSide: 4, level: 4), 4)
        XCTAssertEqual(LifeRoleValues.rentVisitPoints(for: .social, boardSide: 4, level: 4), 2)
        XCTAssertEqual(LifeRoleValues.rentVisitPoints(for: .saver, boardSide: 1, level: 0), 1)
        XCTAssertEqual(LifeRoleValues.rentVisitPoints(for: .saver, boardSide: 4, level: 4), 2)
        for role in LifeRole.allCases where role != .chameleon {
            XCTAssertNotNil(LifeRoleValues.rentVisitLuxuryPerPoint[role], "\(role)")
        }
    }

    func testPayingRentMakesEveryRoleHappierInLuxuriousPlaces() throws {
        var (state, ids) = makeState(roles: [.consumer, .saver, .entrepreneur])
        var luxury = property(group: .darkBlue, owner: ids[2])
        luxury.constructionLevel = 4
        state.properties = [property(owner: ids[2]), luxury]

        var result = try GameRules.collectRent(in: state, from: ids[0], propertyID: state.properties[0].id).state
        result = try GameRules.collectRent(in: result, from: ids[0], propertyID: luxury.id).state
        result = try GameRules.collectRent(in: result, from: ids[1], propertyID: luxury.id).state

        XCTAssertEqual(happiness(ids[0], from: .rentVisit, in: result), 1 + 4)
        XCTAssertEqual(happiness(ids[1], from: .rentVisit, in: result), 2)
        XCTAssertEqual(happiness(ids[2], from: .rentVisit, in: result), 0)
    }

    // MARK: Entrepreneur

    func testEntrepreneurLikesReceivingRentAtMostThreeTimesPerRound() throws {
        var (state, ids) = makeState(roles: [.entrepreneur, .globetrotter])
        state.properties = [property(owner: ids[0])]

        var result = state
        for _ in 0..<4 {
            result = try GameRules.collectRent(in: result, from: ids[1], propertyID: state.properties[0].id).state
        }
        XCTAssertEqual(happiness(ids[0], in: result), 3 * LifeRoleValues.entrepreneurRentReceived)

        result = try finishRound(result)
        XCTAssertEqual(result.monopolife?.profiles[ids[0]]?.scoredRentsThisRound, 0)
    }

    func testEntrepreneurGainsPerLeveledPropertyItManagesCappedAtFour() throws {
        var (state, ids) = makeState(roles: [.entrepreneur, .saver])
        state.properties = ColorGroup.allCases.map { property($0.rawValue, group: $0, owner: ids[0]) }
        for index in 0..<5 {
            state.properties[index].constructionLevel = 1
        }
        state.properties[0].ownership = [PropertyShare(playerID: ids[1], shares: 6), PropertyShare(playerID: ids[0], shares: 4)]
        state.properties[1].ownership = [PropertyShare(playerID: ids[1], shares: 6), PropertyShare(playerID: ids[0], shares: 4)]

        XCTAssertEqual(happiness(ids[0], from: .role(.entrepreneurOwnedProperties), in: try finishRound(state)), 3)

        state.properties[5].constructionLevel = 2
        state.properties[6].constructionLevel = 1
        XCTAssertEqual(happiness(ids[0], from: .role(.entrepreneurOwnedProperties), in: try finishRound(state)), 4)
    }

    func testEntrepreneurDislikesThreeRoundsWithoutLevelingUp() throws {
        var (state, ids) = makeState(roles: [.entrepreneur])
        state.properties = [property(owner: ids[0])]
        GameRules.adjustHappiness(of: ids[0], by: 10, reason: .bankruptcy, in: &state)

        var result = try finishRound(try finishRound(state))
        XCTAssertEqual(happiness(ids[0], in: result), 10)

        result = try finishRound(result)
        XCTAssertEqual(happiness(ids[0], in: result), 10 + LifeRoleValues.entrepreneurStagnation)
        result = try finishRound(result)
        XCTAssertEqual(happiness(ids[0], in: result), 10 + 2 * LifeRoleValues.entrepreneurStagnation)

        result = try GameRules.levelUp(in: result, propertyID: state.properties[0].id, playerID: ids[0])
        result = try finishRound(result)
        XCTAssertEqual(happiness(ids[0], from: .role(.entrepreneurStagnation), in: result), 2 * LifeRoleValues.entrepreneurStagnation)
        XCTAssertEqual(result.monopolife?.profiles[ids[0]]?.roundsWithoutLevelUp, 0)
    }

    func testEntrepreneurDislikesMortgaging() throws {
        var (state, ids) = makeState(roles: [.entrepreneur])
        state.properties = [property(owner: ids[0])]
        GameRules.adjustHappiness(of: ids[0], by: 10, reason: .bankruptcy, in: &state)

        let result = try GameRules.mortgageProperty(in: state, propertyID: state.properties[0].id, playerID: ids[0])

        XCTAssertEqual(happiness(ids[0], in: result), 7)
    }

    // MARK: Saver

    func testSaverGainsPerThreeHundredOfCashWhenEndingTheirTurnCappedAtFive() throws {
        let (state, ids) = makeState(roles: [.saver, .consumer], balance: 1000)
        let afterTurn = try GameRules.endTurn(in: state, playerID: ids[0])
        XCTAssertEqual(happiness(ids[0], in: afterTurn), 3)

        let afterOtherTurn = try GameRules.endTurn(in: afterTurn, playerID: ids[1])
        XCTAssertEqual(happiness(ids[0], in: afterOtherTurn), 3, "Only the saver's own turn counts")

        let (rich, richIDs) = makeState(roles: [.saver], balance: 5000)
        XCTAssertEqual(happiness(richIDs[0], in: try GameRules.endTurn(in: rich, playerID: richIDs[0])), 5)
    }

    func testSaverLikesSalaryOnlyWithoutCardDebt() throws {
        let (state, ids) = makeState(roles: [.saver])
        let debtFree = try GameRules.collectSalary(in: state, playerID: ids[0], amount: 200)
        XCTAssertEqual(happiness(ids[0], in: debtFree), LifeRoleValues.saverSalaryWithoutDebt)

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

        let afterSecondRound = try finishRound(afterTradingRound)
        XCTAssertEqual(happiness(ids[0], in: afterSecondRound), 8, "Rounds without deals only count from round 3")

        let afterQuietRound = try finishRound(afterSecondRound)
        XCTAssertEqual(happiness(ids[0], in: afterQuietRound), 7)
    }

    func testSocialLikesMeetingEachPlayerOverRentOncePerRound() throws {
        var (state, ids) = makeState(roles: [.social, .saver, .saver])
        state.properties = [property(owner: ids[1]), property("B", owner: ids[0]), property("C", owner: ids[2])]

        var result = try GameRules.collectRent(in: state, from: ids[0], propertyID: state.properties[0].id).state
        result = try GameRules.collectRent(in: result, from: ids[1], propertyID: state.properties[1].id).state
        result = try GameRules.collectRent(in: result, from: ids[2], propertyID: state.properties[1].id).state
        result = try GameRules.collectRent(in: result, from: ids[0], propertyID: state.properties[2].id).state
        XCTAssertEqual(happiness(ids[0], from: .role(.socialVisit), in: result), 2)
        XCTAssertEqual(happiness(ids[1], from: .role(.socialVisit), in: result), 0)

        result = try finishRound(result)
        result = try GameRules.collectRent(in: result, from: ids[1], propertyID: state.properties[1].id).state
        XCTAssertEqual(happiness(ids[0], from: .role(.socialVisit), in: result), 3)
    }

    // MARK: Globetrotter

    func testGlobetrotterLikesPassingGo() throws {
        let (state, ids) = makeState(roles: [.globetrotter])

        XCTAssertEqual(
            happiness(ids[0], in: try GameRules.collectSalary(in: state, playerID: ids[0], amount: 200)),
            LifeRoleValues.globetrotterSalary
        )
    }

    func testGlobetrotterStampsEachColorOnceAndGetsTheFullPassportBonus() throws {
        var (state, ids) = makeState(roles: [.globetrotter, .saver], balance: 10_000)
        state.properties = ColorGroup.allCases.map { property($0.rawValue, group: $0, rent: 1, owner: ids[1]) }

        var result = try GameRules.collectRent(in: state, from: ids[0], propertyID: state.properties[0].id).state
        result = try GameRules.collectRent(in: result, from: ids[0], propertyID: state.properties[0].id).state
        XCTAssertEqual(happiness(ids[0], from: .role(.globetrotterStamp), in: result), 3)
        XCTAssertEqual(happiness(ids[0], from: .role(.globetrotterRevisit), in: result), LifeRoleValues.globetrotterRevisit)

        for property in state.properties.dropFirst() {
            result = try GameRules.collectRent(in: result, from: ids[0], propertyID: property.id).state
        }
        XCTAssertEqual(happiness(ids[0], from: .role(.globetrotterStamp), in: result), 8 * 3)
        XCTAssertEqual(happiness(ids[0], from: .role(.globetrotterAllStamps), in: result), 8)
        XCTAssertEqual(happiness(ids[0], from: .role(.globetrotterRevisit), in: result), LifeRoleValues.globetrotterRevisit)
    }

    func testGlobetrotterLikesTravelling() throws {
        let (state, ids) = makeState(roles: [.globetrotter, .saver])

        let trip = try GameRules.payTravel(in: state, playerID: ids[0], route: .nextSide)
        XCTAssertEqual(happiness(ids[0], in: trip), LifeRoleValues.globetrotterTrip)
        XCTAssertEqual(trip.monopolife?.happinessLog.last?.reason, .role(.globetrotterTrip))

        let otherTrip = try GameRules.payTravel(in: state, playerID: ids[1], route: .fullLap)
        XCTAssertEqual(happiness(ids[1], in: otherTrip), 0)
    }

    func testGlobetrotterDislikesBuyingFromTheBankOnlyFromTheThirdProperty() throws {
        var (state, ids) = makeState(roles: [.globetrotter, .globetrotter])
        state.properties = [property(), property("B"), property("C"), property("D", owner: ids[1]), property("E", owner: ids[1])]
        GameRules.adjustHappiness(of: ids[0], by: 5, reason: .bankruptcy, in: &state)
        GameRules.adjustHappiness(of: ids[1], by: 5, reason: .bankruptcy, in: &state)

        let bought = try GameRules.buyProperty(in: state, playerID: ids[0], propertyID: state.properties[0].id)
        XCTAssertEqual(happiness(ids[0], in: bought), 5)

        let auctioned = try GameRules.resolveAuction(
            in: bought,
            propertyID: state.properties[1].id,
            bids: [AuctionBid(playerID: ids[1], amount: 50)]
        )
        XCTAssertEqual(happiness(ids[1], in: auctioned), 5 + LifeRoleValues.globetrotterPropertyBought)
    }

    // MARK: Chameleon

    func testSetupGivesTheChameleonADisguise() throws {
        var generator = SeededGenerator(state: 21)
        let ids = LifeRole.playable.map { _ in UUID() }

        let monopolife = GameRules.makeMonopolifeState(playerIDs: ids, roundLimit: 15, using: &generator)

        XCTAssertEqual(Set(monopolife.profiles.values.map(\.role)), Set(LifeRole.playable))
        XCTAssertFalse(LifeRole.playable.contains(.minimalist))
        XCTAssertFalse(LifeRole.chameleonDisguises.contains(.minimalist))
        for profile in monopolife.profiles.values {
            if profile.role == .chameleon {
                XCTAssertTrue(LifeRole.chameleonDisguises.contains(try XCTUnwrap(profile.disguise)))
            } else {
                XCTAssertNil(profile.disguise)
            }
        }
    }

    func testChameleonLikesWhatItsDisguiseLikes() throws {
        var (state, ids) = makeState(roles: [.chameleon, .consumer], balance: 1000)
        state.monopolife?.profiles[ids[0]]?.disguise = .saver

        let turnEnded = try GameRules.endTurn(in: state, playerID: ids[0])
        XCTAssertEqual(happiness(ids[0], from: .role(.saverSavings), in: turnEnded), 3)

        let salary = try GameRules.collectSalary(in: state, playerID: ids[0], amount: 200)
        XCTAssertEqual(happiness(ids[0], in: salary), LifeRoleValues.saverSalaryWithoutDebt)
    }

    func testChameleonUsesItsDisguiseForLifeCards() throws {
        var (state, ids) = makeState(roles: [.chameleon])
        state.monopolife?.profiles[ids[0]]?.disguise = .globetrotter

        let result = try draw("backpacking", by: ids[0], in: state)

        XCTAssertEqual(happiness(ids[0], in: result), 7)
    }

    func testChameleonChangesDisguiseEveryThreeRoundsButNotAfterTheLast() throws {
        var (state, ids) = makeState(roles: [.chameleon], roundLimit: 6)
        state.monopolife?.profiles[ids[0]]?.disguise = .globetrotter
        state.monopolife?.randomState = 99

        var result = try finishRound(try finishRound(state))
        XCTAssertEqual(result.monopolife?.profiles[ids[0]]?.disguise, .globetrotter)

        result = try finishRound(result)
        let disguise = try XCTUnwrap(result.monopolife?.profiles[ids[0]]?.disguise)
        XCTAssertNotEqual(disguise, .globetrotter)
        XCTAssertEqual(result.monopolife?.happinessLog.last?.reason, .newDisguise(disguise))
        XCTAssertEqual(happiness(ids[0], from: .newDisguise(disguise), in: result), LifeRoleValues.chameleonNewDisguise)

        result = try finishRound(try finishRound(try finishRound(result)))
        XCTAssertEqual(result.monopolife?.isFinished, true)
        XCTAssertEqual(result.monopolife?.profiles[ids[0]]?.disguise, disguise)
    }

    // MARK: Lender

    /// Proposes and accepts the loan, so it is active.
    private func lend(_ loan: PlayerLoan, in state: GameState) throws -> GameState {
        let deal = MarketDeal(
            proposerID: loan.lenderID,
            transfers: [DealTransfer(from: .player(loan.lenderID), to: .player(loan.borrowerID), asset: .money(loan.principal))],
            proposedLoan: loan
        )
        let proposed = try GameRules.proposeDeal(in: state, deal: deal, proposerID: loan.lenderID)
        return try GameRules.acceptDeal(in: proposed, dealID: deal.id, playerID: loan.borrowerID)
    }

    func testLenderLikesLendingWithInterestOncePerRound() throws {
        let (state, ids) = makeState(roles: [.lender, .saver])

        var result = try lend(PlayerLoan(lenderID: ids[0], borrowerID: ids[1], principal: 100, interestPercentage: 10, goPayment: 50), in: state)
        XCTAssertEqual(happiness(ids[0], in: result), LifeRoleValues.lenderLoanGiven)
        result = try lend(PlayerLoan(lenderID: ids[0], borrowerID: ids[1], principal: 200, interestPercentage: 20, goPayment: 50), in: result)
        XCTAssertEqual(happiness(ids[0], in: result), LifeRoleValues.lenderLoanGiven)

        let interestFree = try lend(PlayerLoan(lenderID: ids[0], borrowerID: ids[1], principal: 500, goPayment: 50), in: state)
        XCTAssertEqual(happiness(ids[0], in: interestFree), 0)
    }

    func testLenderLikesTwoPaymentsPerRoundAndBeingPaidOff() throws {
        let (state, ids) = makeState(roles: [.lender, .saver])
        let loan = PlayerLoan(lenderID: ids[0], borrowerID: ids[1], principal: 100, interestPercentage: 20, goPayment: 10)

        var result = try lend(loan, in: state)
        for _ in 0..<3 {
            result = try GameRules.payPlayerLoan(in: result, playerID: ids[1], loanID: loan.id, amount: 10)
        }
        XCTAssertEqual(happiness(ids[0], from: .role(.lenderPaymentReceived), in: result), 2)

        result = try GameRules.payPlayerLoan(in: result, playerID: ids[1], loanID: loan.id, amount: 90)
        XCTAssertEqual(happiness(ids[0], from: .role(.lenderPaymentReceived), in: result), 2)
        XCTAssertEqual(happiness(ids[0], from: .role(.lenderLoanRepaid), in: result), LifeRoleValues.lenderLoanRepaid)
    }

    func testLenderDislikesForgivingAndLikesTakingCollateral() throws {
        var (state, ids) = makeState(roles: [.lender, .saver])
        state.properties = [property(owner: ids[1])]
        GameRules.adjustHappiness(of: ids[0], by: 10, reason: .bankruptcy, in: &state)

        let forgiven = PlayerLoan(lenderID: ids[0], borrowerID: ids[1], principal: 50, goPayment: 10)
        let forgiving = try GameRules.forgivePlayerLoan(in: try lend(forgiven, in: state), playerID: ids[0], loanID: forgiven.id)
        XCTAssertEqual(happiness(ids[0], in: forgiving), 10 + LifeRoleValues.lenderLoanLost)

        var broke = state
        broke.players[1].balance = 0
        let secured = PlayerLoan(
            lenderID: ids[0],
            borrowerID: ids[1],
            principal: 50,
            interestPercentage: 100,
            dueRound: 1,
            collateral: LoanCollateral(propertyID: state.properties[0].id, shares: Property.totalShares)
        )
        let due = try finishRound(try lend(secured, in: broke))
        XCTAssertEqual(due.properties[0].ownerID, ids[0])
        XCTAssertEqual(happiness(ids[0], from: .role(.lenderCollateralTaken), in: due), LifeRoleValues.lenderCollateralTaken)
    }

    // MARK: Rivalry

    func testEveryPlayerGetsARivalAndIsExactlyOnePlayersRival() throws {
        var generator = SeededGenerator(state: 8)
        let ids = (0..<5).map { _ in UUID() }

        let monopolife = GameRules.makeMonopolifeState(playerIDs: ids, roundLimit: 15, using: &generator)

        let rivals = try ids.map { id in try XCTUnwrap(monopolife.profiles[id]?.rivalTargetID) }
        XCTAssertEqual(Set(rivals), Set(ids))
        for (id, rivalID) in zip(ids, rivals) {
            XCTAssertNotEqual(id, rivalID)
        }
        XCTAssertEqual(GameRules.assignRivals(to: [ids[0]], using: &generator), [:])
    }

    func testSavedRivalRolePlaysOnAsSocial() throws {
        let profile = try JSONDecoder().decode(LifeProfile.self, from: Data(#"{"role": "rival"}"#.utf8))
        XCTAssertEqual(profile.role, .social)
    }

    func testEveryRoleWantsMoreNetWorthThanItsRival() throws {
        var (state, ids) = makeState(roles: [.globetrotter, .saver])
        state.monopolife?.profiles[ids[0]]?.rivalTargetID = ids[1]
        GameRules.adjustHappiness(of: ids[0], by: 5, reason: .bankruptcy, in: &state)

        state.players[0].balance = 2000
        XCTAssertEqual(happiness(ids[0], in: try finishRound(state)), 5 + LifeRoleValues.rivalAhead)

        state.players[0].balance = 1000
        XCTAssertEqual(happiness(ids[0], in: try finishRound(state)), 5 + LifeRoleValues.rivalBehind)

        state.players[0].balance = 1500
        XCTAssertEqual(happiness(ids[0], in: try finishRound(state)), 5)
    }

    func testRivalryLikesTheRivalsRentAuctionsAndSetbacks() throws {
        var (state, ids) = makeState(roles: [.globetrotter, .saver, .saver])
        state.monopolife?.profiles[ids[0]]?.rivalTargetID = ids[1]
        state.properties = [property(owner: ids[0]), property("B"), property("C", owner: ids[1])]

        var result = try GameRules.collectRent(in: state, from: ids[1], propertyID: state.properties[0].id).state
        result = try GameRules.collectRent(in: result, from: ids[2], propertyID: state.properties[0].id).state
        XCTAssertEqual(happiness(ids[0], from: .role(.rivalRentFromTarget), in: result), LifeRoleValues.rivalRentFromTarget)

        result = try GameRules.resolveAuction(
            in: result,
            propertyID: state.properties[1].id,
            bids: [AuctionBid(playerID: ids[1], amount: 50), AuctionBid(playerID: ids[0], amount: 60)]
        )
        XCTAssertEqual(happiness(ids[0], from: .role(.rivalAuctionWon), in: result), LifeRoleValues.rivalAuctionWon)

        result = try GameRules.goToJail(in: result, playerID: ids[1])
        result = try GameRules.mortgageProperty(in: result, propertyID: state.properties[2].id, playerID: ids[1])
        result = try GameRules.goToJail(in: result, playerID: ids[2])
        XCTAssertEqual(happiness(ids[0], from: .role(.rivalTargetSetback), in: result), 2 * LifeRoleValues.rivalTargetSetback)

        result = try GameRules.declareBankruptcy(in: result, playerID: ids[1], creditor: .bank)
        XCTAssertEqual(happiness(ids[0], from: .role(.rivalTargetBankrupt), in: result), LifeRoleValues.rivalTargetBankrupt)
    }

    // MARK: Minimalist

    func testMinimalistLikesGivingMoneyAwayUpToThreePointsPerRound() throws {
        let (state, ids) = makeState(roles: [.minimalist, .saver])

        var result = try GameRules.transferMoney(in: state, from: ids[0], to: ids[1], amount: 50)
        XCTAssertEqual(happiness(ids[0], in: result), 0)
        result = try GameRules.transferMoney(in: result, from: ids[0], to: ids[1], amount: 150)
        XCTAssertEqual(happiness(ids[0], in: result), 2)
        result = try GameRules.transferMoney(in: result, from: ids[0], to: ids[1], amount: 500)
        XCTAssertEqual(happiness(ids[0], in: result), LifeRoleValues.minimalistGiftPointsCap)

        result = try finishRound(result)
        XCTAssertEqual(result.monopolife?.profiles[ids[0]]?.moneyGivenThisRound, 0)
        let nextRound = try GameRules.transferMoney(in: result, from: ids[0], to: ids[1], amount: 100)
        XCTAssertEqual(happiness(ids[0], from: .role(.minimalistGift), in: nextRound), LifeRoleValues.minimalistGiftPointsCap + 1)
    }

    func testMinimalistLikesASimpleLife() throws {
        var (state, ids) = makeState(roles: [.minimalist])
        state.properties = [property("A", owner: ids[0]), property("B", owner: ids[0]), property("C")]

        XCTAssertEqual(happiness(ids[0], in: try finishRound(state)), LifeRoleValues.minimalistSimpleLife)

        var cluttered = state
        cluttered.properties[2].ownership = [PropertyShare(playerID: ids[0], shares: 1)]
        XCTAssertEqual(happiness(ids[0], in: try finishRound(cluttered)), 0)

        var withCar = state
        withCar.monopolife?.profiles[ids[0]]?.possessions = [.car]
        XCTAssertEqual(happiness(ids[0], in: try finishRound(withCar)), 0)
    }

    func testMinimalistDislikesGettingPossessions() throws {
        var (state, ids) = makeState(roles: [.minimalist])
        GameRules.adjustHappiness(of: ids[0], by: 10, reason: .bankruptcy, in: &state)

        var result = try draw("buy-car", by: ids[0], in: state)
        result = try GameRules.resolveLifeCardDecision(in: result, playerID: ids[0], accept: true)

        XCTAssertEqual(happiness(ids[0], in: result), 10 + LifeRoleValues.minimalistPossession)
        XCTAssertEqual(result.monopolife?.profiles[ids[0]]?.possessions, [.car])
    }

    // MARK: Jail

    func testGoingToJailCostsEveryRoleTheSame() throws {
        var (state, ids) = makeState(roles: LifeRole.allCases)
        for id in ids {
            GameRules.adjustHappiness(of: id, by: 10, reason: .bankruptcy, in: &state)
        }
        state.monopolife?.profiles[ids[LifeRole.allCases.firstIndex(of: .chameleon)!]]?.disguise = .social

        var result = state
        for id in ids {
            result = try GameRules.goToJail(in: result, playerID: id)
        }

        for id in ids {
            XCTAssertEqual(happiness(id, from: .jail, in: result), LifeRoleValues.jailed)
        }
        let leaving = try GameRules.leaveJail(in: result, playerID: ids[0], exit: .doubles)
        XCTAssertEqual(leaving.monopolife?.happinessLog, result.monopolife?.happinessLog)
    }

    func testJailCardLeavesThePenaltyToTheJailItself() throws {
        let card = try XCTUnwrap(LifeCards.card(withID: "go-to-jail"))
        XCTAssertTrue(card.happiness.values.allSatisfy { $0 == 0 })
    }

    // MARK: Share coverage, board events and host cards

    /// A street held 30% by the first player and 70% by the second, who has no cash.
    private func coveredLevelUp(roles: [LifeRole]) throws -> (state: GameState, ids: [UUID]) {
        var (state, ids) = makeState(roles: roles)
        state.players[1].balance = 0
        var street = property()
        street.ownership = [PropertyShare(playerID: ids[1], shares: 7), PropertyShare(playerID: ids[0], shares: 3)]
        state.properties = [street]
        let result = try GameRules.levelUp(in: state, propertyID: street.id, playerID: ids[0])
        XCTAssertEqual(result.shareCoverages.count, 1)
        return (result, ids)
    }

    func testCoveringAShareholderCountsAsADealForBoth() throws {
        let (result, ids) = try coveredLevelUp(roles: [.social, .social])

        XCTAssertEqual(happiness(ids[0], in: result), LifeRoleValues.socialDeal)
        XCTAssertEqual(happiness(ids[1], in: result), LifeRoleValues.socialDeal)
        XCTAssertEqual(result.monopolife?.profiles[ids[1]]?.tookPartInDealThisRound, true)
    }

    func testBuyingSharesBackCountsAsADeal() throws {
        var (state, ids) = try coveredLevelUp(roles: [.saver, .social])
        state.players[1].balance = 1_000

        let result = try GameRules.buyBackShares(in: state, coverageID: state.shareCoverages[0].id, playerID: ids[1])

        XCTAssertEqual(happiness(ids[1], in: result), LifeRoleValues.socialDeal * 2)
    }

    func testHostCardFreeLevelUpIsNotALevelUpForTheConsumer() throws {
        var (state, ids) = makeState(roles: [.consumer])
        state.properties = [property(owner: ids[0])]

        let result = try GameRules.playHostCard(
            HostCardPlay(card: .advanceAndLevelUp, playerID: ids[0], propertyID: state.properties[0].id),
            in: state
        )

        XCTAssertEqual(result.properties[0].constructionLevel, 1)
        XCTAssertEqual(happiness(ids[0], in: result), 0)
    }

    func testSharedPurchaseCountsForEachBuyer() throws {
        var (state, ids) = makeState(roles: [.globetrotter, .globetrotter])
        state.properties = [property()] + ids.flatMap { id in [property("A", owner: id), property("B", owner: id)] }
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

        XCTAssertEqual(happiness(ids[1], in: tax), 0)
        XCTAssertEqual(tax.monopolife?.happinessLog.map(\.reason), [.rentVisit], "Only the rent visit every role gets")
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
            XCTAssertEqual(Set(card.happiness.keys), Set(LifeRole.allCases.filter { $0 != .chameleon }), card.id)
        }
    }

    /// MONOPOLIFE_RULES 3.2: what each role can get from the whole deck (decisions
    /// only count when positive, since they can be passed) stays within ±2.
    func testDeckIsBalancedAcrossRoles() {
        let totals = LifeRole.allCases.filter { $0 != .chameleon }.map { role in
            LifeCards.all.reduce(0) { total, card in
                let value = card.happiness(for: role)
                return total + (card.kind == .decision ? max(0, value) : value)
            }
        }
        XCTAssertLessThanOrEqual(totals.max()! - totals.min()!, 2, "Totals by role: \(totals)")
    }

    func testDeckHasBadLuckCards() {
        let badForEveryone = LifeCards.all.filter { card in card.happiness.values.allSatisfy { $0 <= 0 } }
        XCTAssertGreaterThanOrEqual(badForEveryone.count, 8)
    }

    // MARK: Life Cards: dealt by the host

    func testRequestedCardWaitsForTheHostToDealIt() throws {
        let (state, ids) = makeState(roles: [.saver, .consumer])
        var generator = SeededGenerator(state: 4)

        let requested = try GameRules.requestLifeCard(in: state, playerID: ids[0])
        XCTAssertEqual(requested.monopolife?.lifeCardRequest, ids[0])
        XCTAssertNil(requested.monopolife?.lastLifeCardDraw)
        XCTAssertThrowsError(try GameRules.requestLifeCard(in: requested, playerID: ids[0])) { error in
            XCTAssertEqual(error as? GameRuleError, .lifeCardRequestPending)
        }
        XCTAssertThrowsError(try GameRules.endTurn(in: requested, playerID: ids[0])) { error in
            XCTAssertEqual(error as? GameRuleError, .lifeCardRequestPending)
        }

        let dealt = try GameRules.dealLifeCard(in: requested, favorable: false, using: &generator)
        XCTAssertNil(dealt.monopolife?.lifeCardRequest)
        XCTAssertEqual(dealt.monopolife?.lastLifeCardDraw?.playerID, ids[0])
        XCTAssertEqual(dealt.monopolife?.lastLifeCardDraw?.cardID, state.monopolife?.lifeDeck.first)
        XCTAssertThrowsError(try GameRules.dealLifeCard(in: dealt, favorable: false, using: &generator)) { error in
            XCTAssertEqual(error as? GameRuleError, .noLifeCardRequest)
        }
    }

    func testFavorableCardIsGoodForThePlayersRoleAndLeavesTheDeck() throws {
        for role in LifeRole.playable {
            var (state, ids) = makeState(roles: [role])
            state.monopolife?.profiles[ids[0]]?.disguise = .social
            var generator = SeededGenerator(state: 12)

            let requested = try GameRules.requestLifeCard(in: state, playerID: ids[0])
            let dealt = try GameRules.dealLifeCard(in: requested, favorable: true, using: &generator)

            let cardID = try XCTUnwrap(dealt.monopolife?.lastLifeCardDraw?.cardID)
            let card = try XCTUnwrap(LifeCards.card(withID: cardID))
            let profile = try XCTUnwrap(state.monopolife?.profiles[ids[0]])
            XCTAssertGreaterThan(card.happiness(for: profile.activeRole), 0, "\(role)")
            XCTAssertFalse(dealt.monopolife?.lifeDeck.contains(cardID) ?? true, "\(role)")
            XCTAssertEqual(dealt.monopolife?.lifeDeck.count, LifeCards.all.count - 1)
        }
    }

    func testFavorableCardComesFromTheWholeDeckWhenNoneIsLeft() throws {
        var (state, ids) = makeState(roles: [.saver])
        state.monopolife?.lifeDeck = ["sick", "traffic-fine"]
        var generator = SeededGenerator(state: 3)

        let dealt = try GameRules.drawLifeCard(in: state, playerID: ids[0], favorable: true, using: &generator)

        let cardID = try XCTUnwrap(dealt.monopolife?.lastLifeCardDraw?.cardID)
        XCTAssertGreaterThan(try XCTUnwrap(LifeCards.card(withID: cardID)).happiness(for: .saver), 0)
        XCTAssertEqual(dealt.monopolife?.lifeDeck, ["sick", "traffic-fine"])
    }

    func testDealLifeCardIntentRoundTrips() throws {
        let intent = GameIntent.dealLifeCard(favorable: true)
        XCTAssertEqual(try JSONDecoder().decode(GameIntent.self, from: JSONEncoder().encode(intent)), intent)
        XCTAssertFalse(intent.requiresTurn)
        XCTAssertTrue(GameIntent.drawLifeCard(playerID: UUID()).requiresTurn)
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
        var (state, ids) = makeState(roles: [.saver], balance: 0)
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
        let (state, ids) = makeState(roles: [.social, .saver, .globetrotter])

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
