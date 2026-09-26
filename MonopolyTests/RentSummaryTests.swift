import XCTest
@testable import Monopoly

/// The "Rentas modificadas" card sums rent effects per part of the board instead of
/// listing every card and event.
final class RentSummaryTests: XCTestCase {
    private func makeState(hostEffects: [ActiveRentEffect] = [], eventEffects: [ActiveRentEffect] = []) -> GameState {
        var state = GameState(players: [], properties: PlaceholderProperties.all, hostCardRentEffects: hostEffects)
        if !eventEffects.isEmpty {
            state.boardEvents = BoardEventsState(interval: 3, randomState: 1, rentEffects: eventEffects)
        }
        return state
    }

    private func ids(_ state: GameState, where include: (Property) -> Bool) -> Set<UUID> {
        Set(state.properties.filter(include).map(\.id))
    }

    private func effect(_ ids: Set<UUID>, flat: Int = 0, percent: Int = 0, lastRound: Int? = nil) -> ActiveRentEffect {
        ActiveRentEffect(eventID: HostCard.rentRaiseOnSide.rawValue, propertyIDs: ids, flat: flat, percent: percent, lastRound: lastRound)
    }

    func testManyCardsOnTheSameSideAreOneRow() {
        let base = makeState()
        let sideOne = ids(base) { $0.colorGroup.boardSide == 1 }
        let state = makeState(hostEffects: (1...12).map { _ in effect(sideOne, flat: 100) })

        let summary = GameRules.rentChangeSummary(in: state)

        XCTAssertEqual(summary.count, 1)
        XCTAssertEqual(summary[0].scope, .side(1))
        XCTAssertEqual(summary[0].flat, 1_200)
        XCTAssertEqual(summary[0].effects.count, 12)
    }

    func testTheRowsNeverOutgrowTheBoardSides() {
        let base = makeState()
        let effects = (0..<40).map { index in
            effect(ids(base) { $0.colorGroup.boardSide == index % 4 + 1 }, flat: index % 3 == 0 ? -100 : 100)
        }

        let summary = GameRules.rentChangeSummary(in: makeState(hostEffects: effects))

        XCTAssertLessThanOrEqual(summary.count, 4)
    }

    func testChangesThatCancelOutDisappear() {
        let base = makeState()
        let sideTwo = ids(base) { $0.colorGroup.boardSide == 2 }
        let state = makeState(hostEffects: [effect(sideTwo, flat: 100), effect(sideTwo, flat: -100)])

        XCTAssertTrue(GameRules.rentChangeSummary(in: state).isEmpty)
    }

    func testTheWholeBoardIsOneRow() {
        let base = makeState()
        let state = makeState(eventEffects: [effect(ids(base) { _ in true }, percent: 25, lastRound: 4)])

        let summary = GameRules.rentChangeSummary(in: state)

        XCTAssertEqual(summary.map(\.scope), [.wholeBoard])
        XCTAssertEqual(summary[0].percent, 25)
    }

    func testASideSplitsOnlyWhereItDiffers() throws {
        let base = makeState()
        let sideThree = ids(base) { $0.colorGroup.boardSide == 3 }
        let red = ids(base) { $0.colorGroup == .red }
        let oneYellow = try XCTUnwrap(base.properties.first { $0.colorGroup == .yellow })
        let state = makeState(
            hostEffects: [effect(sideThree, flat: 100)],
            eventEffects: [effect(red, percent: 50), effect([oneYellow.id], flat: 150)]
        )

        let summary = GameRules.rentChangeSummary(in: state)

        XCTAssertEqual(summary.map(\.scope), [.colorGroup(.red), .property(oneYellow.id)] + base.properties
            .filter { $0.colorGroup == .yellow && $0.id != oneYellow.id }
            .map { .property($0.id) })
        XCTAssertEqual(summary[0].percent, 50)
        XCTAssertEqual(summary[0].flat, 100)
        XCTAssertEqual(summary[1].flat, 250)
        XCTAssertEqual(summary[0].effects.count, 2)
    }
}
