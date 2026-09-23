import XCTest
@testable import Monopoly

final class BoardEventsTests: XCTestCase {
    private let ana = Player(name: "Ana", balance: 1000)
    private let luis = Player(name: "Luis", balance: 1000)

    private func makeState(
        interval: Int? = 3,
        properties: [Property]? = nil,
        rules: Set<HouseRule> = [],
        seed: UInt64 = 1
    ) -> GameState {
        GameState(
            players: [ana, luis],
            properties: properties ?? [
                street("Brown", .brown, owner: luis.id),
                street("Pink", .pink, owner: luis.id),
                street("Red", .red, owner: nil),
                street("Green", .green, owner: luis.id)
            ],
            currentPlayerID: ana.id,
            activeHouseRules: rules,
            boardEvents: interval.map { BoardEventsState(interval: $0, randomState: seed) }
        )
    }

    private func street(_ name: String, _ group: ColorGroup, rent: Int = 100, owner: UUID?, level: Int = 0) -> Property {
        Property(
            name: name,
            colorGroup: group,
            purchasePrice: 200,
            mortgageValue: 100,
            baseRent: rent,
            rentByConstructionLevel: [rent, rent * 2, rent * 3, rent * 4, rent * 5, rent * 6],
            constructionLevel: level,
            ownerID: owner
        )
    }

    private func event(_ id: String) throws -> BoardEvent {
        try XCTUnwrap(BoardEventCatalog.event(withID: id))
    }

    private func rent(of index: Int, in state: GameState) throws -> Int {
        try GameRules.collectRent(in: state, from: ana.id, propertyID: state.properties[index].id).amount
    }

    private func finishRound(_ state: GameState) throws -> GameState {
        var updated = try GameRules.endTurn(in: state, playerID: ana.id)
        updated = try GameRules.endTurn(in: updated, playerID: luis.id)
        return updated
    }

    // MARK: Catalog

    func testCatalogHasAtLeastTwelveDistinctEvents() {
        XCTAssertGreaterThanOrEqual(BoardEventCatalog.all.count, 12)
        XCTAssertEqual(Set(BoardEventCatalog.all.map(\.id)).count, BoardEventCatalog.all.count)
    }

    func testSidesFollowTheBoard() {
        XCTAssertEqual(ColorGroup.brown.boardSide, 1)
        XCTAssertEqual(ColorGroup.orange.boardSide, 2)
        XCTAssertEqual(ColorGroup.yellow.boardSide, 3)
        XCTAssertEqual(ColorGroup.darkBlue.boardSide, 4)
    }

    // MARK: Rent effects

    func testTornadoTakesTwoHundredOffASideForThreeRoundsNeverBelowZero() throws {
        var state = makeState(properties: [street("A", .brown, rent: 300, owner: luis.id), street("B", .lightBlue, rent: 50, owner: luis.id), street("C", .pink, owner: luis.id)])
        GameRules.happen(try event("tornado"), on: .side(1), afterRound: 3, in: &state)

        XCTAssertEqual(try rent(of: 0, in: state), 100)
        XCTAssertEqual(try rent(of: 1, in: state), 0)
        XCTAssertEqual(try rent(of: 2, in: state), 100)
        XCTAssertEqual(state.boardEvents?.rentEffects.first?.lastRound, 6)
    }

    func testPercentagesApplyBeforeFlatAmountsAndEffectsStack() throws {
        var state = makeState()
        GameRules.happen(try event("celebrity"), on: .colorGroup(.brown), afterRound: 3, in: &state)
        GameRules.happen(try event("summer-festival"), on: .side(1), afterRound: 3, in: &state)

        XCTAssertEqual(try rent(of: 0, in: state), 100 * 2 + 100)
    }

    func testRoadworksZeroesOneProperty() throws {
        var state = makeState()
        GameRules.happen(try event("roadworks"), on: .property(state.properties[1].id), afterRound: 3, in: &state)

        XCTAssertEqual(try rent(of: 1, in: state), 0)
        XCTAssertEqual(try rent(of: 0, in: state), 100)
    }

    func testMortgagedPropertyStillCollectsNothing() throws {
        var state = makeState()
        state.properties[0].isMortgaged = true
        GameRules.happen(try event("neighborhood-award"), on: .property(state.properties[0].id), afterRound: 3, in: &state)

        XCTAssertEqual(try rent(of: 0, in: state), 0)
    }

    func testTemporaryEffectsExpireAndPermanentOnesStay() throws {
        var state = makeState(interval: 100)
        GameRules.happen(try event("blackout"), on: .side(1), afterRound: 1, in: &state)
        GameRules.happen(try event("subway"), on: .side(1), afterRound: 1, in: &state)
        XCTAssertEqual(state.round, 1)
        XCTAssertEqual(try rent(of: 0, in: state), 100)

        state = try finishRound(state)
        XCTAssertEqual(state.round, 2)
        XCTAssertEqual(try rent(of: 0, in: state), 100)

        state = try finishRound(state)
        XCTAssertEqual(state.round, 3)
        XCTAssertEqual(try rent(of: 0, in: state), 150)
        XCTAssertEqual(state.boardEvents?.rentEffects.map(\.eventID), ["subway"])
    }

    func testRentEffectsShowInTheRentShownToPlayers() throws {
        var state = makeState()
        GameRules.happen(try event("housing-boom"), on: .wholeBoard, afterRound: 3, in: &state)

        XCTAssertEqual(try GameRules.rentAmount(for: state.properties[0], in: state, ownerID: luis.id), 125)
    }

    // MARK: Other effects

    func testFloodChargesShareholdersByStakeAndFillsThePot() throws {
        var properties = [street("A", .brown, owner: luis.id), street("B", .lightBlue, owner: nil)]
        properties[0].ownership = [PropertyShare(playerID: luis.id, shares: 6), PropertyShare(playerID: ana.id, shares: 4)]
        var state = makeState(properties: properties, rules: [.freeParkingJackpot])

        GameRules.happen(try event("flood"), on: .side(1), afterRound: 3, in: &state)

        XCTAssertEqual(state.players[0].balance, 980)
        XCTAssertEqual(state.players[1].balance, 970)
        XCTAssertEqual(state.freeParkingPot, 50)
    }

    func testChargesNeverGoBelowZero() throws {
        var state = makeState()
        state.players[1].balance = 10

        GameRules.happen(try event("flood"), on: .side(1), afterRound: 3, in: &state)

        XCTAssertEqual(state.players[1].balance, 0)
    }

    func testSubsidyPaysEveryActivePlayer() throws {
        var state = makeState()
        state.players[1].status = .bankrupt

        GameRules.happen(try event("subsidy"), on: .allPlayers, afterRound: 3, in: &state)

        XCTAssertEqual(state.players.map(\.balance), [1100, 1000])
    }

    func testFireLowersALevelWithoutRefundAndNeedsALeveledProperty() throws {
        var state = makeState()
        XCTAssertTrue(GameRules.targets(for: try event("fire"), in: state).isEmpty)

        state.properties[0].constructionLevel = 2
        let targets = GameRules.targets(for: try event("fire"), in: state)
        XCTAssertEqual(targets, [.property(state.properties[0].id)])

        GameRules.happen(try event("fire"), on: targets[0], afterRound: 3, in: &state)
        XCTAssertEqual(state.properties[0].constructionLevel, 1)
        XCTAssertEqual(state.players[1].balance, 1000)
    }

    // MARK: Timing and draws

    func testAnEventHappensAtTheEndOfEveryIntervalRounds() throws {
        var state = makeState(interval: 2)
        state = try finishRound(state)
        XCTAssertEqual(state.boardEvents?.history.count, 0)

        state = try finishRound(state)
        XCTAssertEqual(state.boardEvents?.history.count, 1)
        XCTAssertEqual(state.boardEvents?.history.first?.round, 2)
        XCTAssertEqual(state.boardEvents?.history.first?.sequence, 1)

        state = try finishRound(state)
        state = try finishRound(state)
        XCTAssertEqual(state.boardEvents?.history.map(\.sequence), [1, 2])
    }

    func testAnyFixedIntervalWorks() throws {
        var everyRound = makeState(interval: 1)
        var everySeven = makeState(interval: 7)
        for _ in 0..<14 {
            everyRound = try finishRound(everyRound)
            everySeven = try finishRound(everySeven)
            everyRound.players = everyRound.players.map { var player = $0; player.balance = 1000; return player }
            everySeven.players = everySeven.players.map { var player = $0; player.balance = 1000; return player }
        }
        XCTAssertEqual(everyRound.boardEvents?.history.map(\.round), Array(1...14))
        XCTAssertEqual(everySeven.boardEvents?.history.map(\.round), [7, 14])
        XCTAssertEqual(everySeven.boardEvents?.nextEventRound, 21)
    }

    func testRandomGapsStayWithinTheRangeAndVary() throws {
        var state = GameState(
            players: [ana, luis],
            properties: [street("Brown", .brown, owner: luis.id)],
            currentPlayerID: ana.id,
            boardEvents: BoardEventsState(interval: 2, maxInterval: 6, randomState: 9)
        )
        XCTAssertTrue((2...6).contains(state.boardEvents?.nextEventRound ?? 0))

        for _ in 0..<120 {
            state = try finishRound(state)
            state.players = state.players.map { var player = $0; player.balance = 1000; return player }
        }
        let rounds = [0] + (state.boardEvents?.history.map(\.round) ?? [])
        let gaps = zip(rounds.dropFirst(), rounds).map { $0 - $1 }
        XCTAssertGreaterThan(gaps.count, 15)
        XCTAssertTrue(gaps.allSatisfy { (2...6).contains($0) }, "\(gaps)")
        XCTAssertGreaterThan(Set(gaps).count, 1)
    }

    func testRandomScheduleIsReproducibleFromTheSeed() {
        let first = BoardEventsState(interval: 1, maxInterval: 10, randomState: 5)
        let second = BoardEventsState(interval: 1, maxInterval: 10, randomState: 5)

        XCTAssertEqual(first.nextEventRound, second.nextEventRound)
        XCTAssertEqual(first.randomState, second.randomState)
    }

    func testGamesSavedBeforeTheScheduleKeepEveryIntervalRounds() throws {
        let data = try JSONEncoder().encode(BoardEventsState(interval: 3, randomState: 1))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "nextEventRound")
        json.removeValue(forKey: "maxInterval")

        let legacy = try JSONDecoder().decode(BoardEventsState.self, from: JSONSerialization.data(withJSONObject: json))

        XCTAssertNil(legacy.nextEventRound)
        XCTAssertEqual(legacy.maxInterval, 3)
        XCTAssertFalse(legacy.isEventDue(afterRound: 4))
        XCTAssertTrue(legacy.isEventDue(afterRound: 6))
        XCTAssertEqual(legacy.upcomingEventRound(from: 4), 6)
    }

    func testNoEventsWhenTurnedOff() throws {
        var state = makeState(interval: nil)
        for _ in 0..<6 {
            state = try finishRound(state)
        }
        XCTAssertNil(state.boardEvents)
        XCTAssertEqual(try rent(of: 0, in: state), 100)
    }

    func testDrawsAreReproducibleFromTheSeed() throws {
        let first = try finishRound(try finishRound(try finishRound(makeState(seed: 42))))
        let second = try finishRound(try finishRound(try finishRound(makeState(seed: 42))))

        XCTAssertEqual(first.boardEvents?.history.map(\.eventID), second.boardEvents?.history.map(\.eventID))
        XCTAssertEqual(first.boardEvents?.history.map(\.target), second.boardEvents?.history.map(\.target))
        XCTAssertNotEqual(first.boardEvents?.randomState, 42)
    }

    func testDrawsCoverManyEventsOverALongGame() throws {
        var state = makeState(interval: 1, seed: 7)
        state.properties[0].constructionLevel = 1
        for _ in 0..<80 {
            state = try finishRound(state)
            state.players = state.players.map { var player = $0; player.balance = 1000; return player }
        }
        XCTAssertGreaterThanOrEqual(Set(state.boardEvents?.history.map(\.eventID) ?? []).count, 10)
    }

    func testNoEventAfterTheLastMonopolifeRound() throws {
        var state = makeState(interval: 2)
        state.mode = .monopolife
        state.monopolife = MonopolifeState(
            roundLimit: 2,
            profiles: [ana.id: LifeProfile(role: .saver), luis.id: LifeProfile(role: .consumer)]
        )

        state = try finishRound(try finishRound(state))

        XCTAssertEqual(state.monopolife?.isFinished, true)
        XCTAssertEqual(state.boardEvents?.history.count, 0)
    }

    // MARK: Setup and saves

    func testLobbyTurnsEventsOn() {
        let players = [LobbyPlayer(name: "Ana", isHostControlled: true), LobbyPlayer(name: "Luis", isHostControlled: false)]

        let on = Lobby(players: players, boardEventInterval: 4).makeGameState(initialBalance: 1500, properties: [])
        let off = Lobby(players: players).makeGameState(initialBalance: 1500, properties: [])

        XCTAssertEqual(on.boardEvents?.interval, 4)
        XCTAssertNil(off.boardEvents)

        let random = Lobby(players: players, boardEventInterval: 2, boardEventMaxInterval: 5).makeGameState(initialBalance: 1500, properties: [])
        XCTAssertEqual(random.boardEvents?.maxInterval, 5)
        XCTAssertEqual(random.boardEvents?.hasRandomInterval, true)
    }

    func testStateRoundTripsAndOlderSavesHaveNoEvents() throws {
        var state = makeState()
        GameRules.happen(try event("tornado"), on: .side(2), afterRound: 3, in: &state)
        XCTAssertEqual(try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state)), state)

        let data = try JSONEncoder().encode(makeState(interval: nil))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "boardEvents")
        let legacy = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(legacy.boardEvents)
    }
}
