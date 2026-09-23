import Foundation

struct PropertyShare: Codable, Equatable {
    let playerID: UUID
    var shares: Int
}

struct Property: Identifiable, Codable, Equatable {
    /// A property is split into 10 shares of 10% each.
    static let totalShares = 10

    /// Percentage of the purchase price charged when reaching each level.
    /// The array is indexed by `level - 1` and applies to every property.
    static let levelUpCostPercentages = [50, 75, 100, 150, 200]
    static let maximumLevel = levelUpCostPercentages.count

    let id: UUID
    var name: String
    var colorGroup: ColorGroup
    var purchasePrice: Int
    var mortgageValue: Int
    var baseRent: Int
    var rentByConstructionLevel: [Int]
    var constructionLevel: Int
    /// Shareholders in the order they acquired their first share; empty while the
    /// bank owns the property.
    var ownership: [PropertyShare]
    var isMortgaged: Bool

    /// The majority shareholder, who manages the property (builds, mortgages, sells
    /// buildings) and counts as its owner for color-group monopolies. On a tie the
    /// earliest shareholder manages.
    var ownerID: UUID? {
        var manager: PropertyShare?
        for holding in ownership where holding.shares > (manager?.shares ?? 0) {
            manager = holding
        }
        return manager?.playerID
    }

    var isOwned: Bool {
        !ownership.isEmpty
    }

    func shares(of playerID: UUID) -> Int {
        ownership.first(where: { $0.playerID == playerID })?.shares ?? 0
    }

    mutating func addShares(_ count: Int, to playerID: UUID) {
        if let index = ownership.firstIndex(where: { $0.playerID == playerID }) {
            ownership[index].shares += count
        } else {
            ownership.append(PropertyShare(playerID: playerID, shares: count))
        }
    }

    mutating func removeShares(_ count: Int, from playerID: UUID) {
        guard let index = ownership.firstIndex(where: { $0.playerID == playerID }) else {
            return
        }
        ownership[index].shares -= count
        if ownership[index].shares <= 0 {
            ownership.remove(at: index)
        }
    }

    init(
        id: UUID = UUID(),
        name: String,
        colorGroup: ColorGroup,
        purchasePrice: Int,
        mortgageValue: Int,
        baseRent: Int,
        rentByConstructionLevel: [Int]? = nil,
        constructionLevel: Int = 0,
        ownerID: UUID? = nil,
        ownership: [PropertyShare]? = nil,
        isMortgaged: Bool = false
    ) {
        self.id = id
        self.name = name
        self.colorGroup = colorGroup
        self.purchasePrice = purchasePrice
        self.mortgageValue = mortgageValue
        self.baseRent = baseRent
        self.rentByConstructionLevel = rentByConstructionLevel ?? [
            baseRent,
            baseRent * 5,
            baseRent * 15,
            baseRent * 35,
            baseRent * 50,
            baseRent * 70
        ]
        self.constructionLevel = constructionLevel
        self.ownership = ownership
            ?? ownerID.map { [PropertyShare(playerID: $0, shares: Self.totalShares)] }
            ?? []
        self.isMortgaged = isMortgaged
    }

    /// Cost of reaching `level` from the previous level, rounded up.
    static func levelUpCost(purchasePrice: Int, level: Int) -> Int {
        guard level >= 1, level <= levelUpCostPercentages.count else {
            return 0
        }
        let percentage = levelUpCostPercentages[level - 1]
        return (purchasePrice * percentage + 99) / 100
    }
}
