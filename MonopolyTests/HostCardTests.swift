import XCTest
@testable import Monopoly

/// GAME_RULES section 8.5: cards only the host resolves.
final class HostCardTests: XCTestCase {
    private let ana = Player(name: "Ana", balance: 1_000)
    private let luis = Player(name: "Luis", balance: 1_000)

    /// One property per side, owned by Luis, each with a $200 rent.
    private func makeState(round: Int = 1) -> GameState {
        let groups: [ColorGroup] = [.brown, .pink, .red, .green]
        let properties = groups.map {
            Property(name: $0.rawValue, colorGroup: $0, purchasePrice: 100, mortgageValue: 50, baseRent: 200, ownerID: luis.id)
        }
        return GameState(players: [ana, luis], properties: properties, currentPlayerID: ana.id, round: round)
    }

    private func rents(in state: GameState) throws -> [Int] {
        try state.properties.map { try GameRules.rentAmount(for: $0, in: state, ownerID: luis.id) }
    }

    func testRentDropAndRaiseChangeOneSide() throws {
        let base = makeState()

        let dropped = try GameRules.playHostCard(HostCardPlay(card: .rentDropOnSide, side: 2), in: base)
        XCTAssertEqual(try rents(in: dropped), [200, 100, 200, 200])

        let raised = try GameRules.playHostCard(HostCardPlay(card: .rentRaiseOnSide, side: 4), in: base)
        XCTAssertEqual(try rents(in: raised), [200, 200, 200, 300])
    }

    func testRentShiftRaisesOneSideAndDropsItsNeighbors() throws {
        let state = try GameRules.playHostCard(HostCardPlay(card: .rentShiftToSide, side: 1), in: makeState())

        XCTAssertEqual(try rents(in: state), [300, 100, 200, 100])
        XCTAssertEqual(BoardEventsState.neighbors(ofSide: 2), [1, 3])
    }

    func testRentChangesWorkWithoutBoardEventsAndExpireAfterTheirRounds() throws {
        var state = try GameRules.playHostCard(HostCardPlay(card: .rentRaiseOnSide, side: 1, rounds: 2), in: makeState(round: 3))
        XCTAssertNil(state.boardEvents)

        GameRules.expireHostCardEffects(afterRound: 3, in: &state)
        XCTAssertEqual(try rents(in: state)[0], 300)

        GameRules.expireHostCardEffects(afterRound: 4, in: &state)
        XCTAssertEqual(try rents(in: state)[0], 200)
        XCTAssertTrue(state.hostCardRentEffects.isEmpty)
    }

    func testPermanentRentChangesNeverExpire() throws {
        var state = try GameRules.playHostCard(HostCardPlay(card: .rentDropOnSide, side: 1), in: makeState())

        GameRules.expireHostCardEffects(afterRound: 50, in: &state)

        XCTAssertEqual(try rents(in: state)[0], 100)
    }

    func testRentCardsNeedAValidSideAndDuration() {
        XCTAssertThrowsError(try GameRules.playHostCard(HostCardPlay(card: .rentDropOnSide, side: 5), in: makeState())) { error in
            XCTAssertEqual(error as? GameRuleError, .invalidBoardSide(5))
        }
        XCTAssertThrowsError(try GameRules.playHostCard(HostCardPlay(card: .rentDropOnSide, side: 1, rounds: 0), in: makeState())) { error in
            XCTAssertEqual(error as? GameRuleError, .invalidAmount(0))
        }
    }

    func testAdvanceAndLevelUpRaisesAnyOwnedPropertyForFree() throws {
        let base = makeState()
        let propertyID = base.properties[0].id

        let state = try GameRules.playHostCard(
            HostCardPlay(card: .advanceAndLevelUp, playerID: ana.id, propertyID: propertyID),
            in: base
        )

        XCTAssertEqual(state.properties[0].constructionLevel, 1)
        XCTAssertEqual(state.players.map(\.balance), base.players.map(\.balance))
        XCTAssertEqual(state.lastHostCard?.sequence, 1)
    }

    func testAdvanceAndLevelUpNeedsAnOwnedPropertyBelowTheMaximum() {
        var state = makeState()
        state.properties[0].ownership = []
        state.properties[1].constructionLevel = Property.maximumLevel

        XCTAssertThrowsError(try GameRules.playHostCard(
            HostCardPlay(card: .advanceAndLevelUp, playerID: ana.id, propertyID: state.properties[0].id), in: state
        )) { error in
            XCTAssertEqual(error as? GameRuleError, .propertyHasNoOwner(state.properties[0].id))
        }
        XCTAssertThrowsError(try GameRules.playHostCard(
            HostCardPlay(card: .advanceAndLevelUp, playerID: ana.id, propertyID: state.properties[1].id), in: state
        )) { error in
            XCTAssertEqual(error as? GameRuleError, .propertyAtMaximumLevel(state.properties[1].id))
        }
        XCTAssertThrowsError(try GameRules.playHostCard(HostCardPlay(card: .advanceAndLevelUp), in: state)) { error in
            XCTAssertEqual(error as? GameRuleError, .incompleteHostCard)
        }
    }

    func testIntentAndStateRoundTrip() throws {
        let intent = GameIntent.playHostCard(HostCardPlay(card: .rentShiftToSide, side: 3, rounds: 2))
        XCTAssertEqual(try JSONDecoder().decode(GameIntent.self, from: JSONEncoder().encode(intent)), intent)
        XCTAssertFalse(intent.requiresTurn)

        let state = try GameRules.playHostCard(HostCardPlay(card: .rentRaiseOnSide, side: 1), in: makeState())
        XCTAssertEqual(try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state)), state)
    }
}
