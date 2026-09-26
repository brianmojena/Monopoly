import Foundation

/// The net rent change on part of the board, from every board event and host card
/// touching it.
struct RentChangeGroup: Equatable {
    let scope: BoardEventTarget
    let percent: Int
    let flat: Int
    /// The effects behind it, in the order they were applied.
    let effects: [ActiveRentEffect]
}

extension GameRules {
    /// Every rent effect in play: board events first, then host cards.
    static func activeRentEffects(in state: GameState) -> [ActiveRentEffect] {
        (state.boardEvents?.rentEffects ?? []) + state.hostCardRentEffects
    }

    /// Rent changes summed per part of the board, so the list stays short however many
    /// effects pile up: one row for the whole board when it all changed the same, else
    /// one per side, split into color groups or single properties only where they
    /// differ. Parts with no net change are left out.
    static func rentChangeSummary(in state: GameState) -> [RentChangeGroup] {
        let effects = activeRentEffects(in: state)
        guard !effects.isEmpty, !state.properties.isEmpty else {
            return []
        }

        func net(_ property: Property) -> RentNet {
            effects.filter { $0.propertyIDs.contains(property.id) }.reduce(RentNet()) {
                RentNet(percent: $0.percent + $1.percent, flat: $0.flat + $1.flat)
            }
        }
        func group(_ scope: BoardEventTarget, _ properties: [Property]) -> [RentChangeGroup] {
            let nets = Set(properties.map(net))
            guard nets.count == 1, let only = nets.first else {
                return []
            }
            guard !only.isZero else {
                return []
            }
            let ids = Set(properties.map(\.id))
            return [RentChangeGroup(
                scope: scope,
                percent: only.percent,
                flat: only.flat,
                effects: effects.filter { !$0.propertyIDs.isDisjoint(with: ids) }
            )]
        }
        func isUniform(_ properties: [Property]) -> Bool {
            Set(properties.map(net)).count == 1
        }

        if isUniform(state.properties) {
            return group(.wholeBoard, state.properties)
        }

        var summary: [RentChangeGroup] = []
        for side in 1...4 {
            let sideProperties = state.properties.filter { $0.colorGroup.boardSide == side }
            guard !sideProperties.isEmpty else { continue }
            if isUniform(sideProperties) {
                summary += group(.side(side), sideProperties)
                continue
            }
            for colorGroup in ColorGroup.allCases where colorGroup.boardSide == side {
                let groupProperties = sideProperties.filter { $0.colorGroup == colorGroup }
                guard !groupProperties.isEmpty else { continue }
                if isUniform(groupProperties) {
                    summary += group(.colorGroup(colorGroup), groupProperties)
                } else {
                    for property in groupProperties {
                        summary += group(.property(property.id), [property])
                    }
                }
            }
        }
        return summary
    }
}

private struct RentNet: Hashable {
    var percent = 0
    var flat = 0

    var isZero: Bool {
        percent == 0 && flat == 0
    }
}
