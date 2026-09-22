import Foundation

struct Property: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var colorGroup: ColorGroup
    var purchasePrice: Int
    var mortgageValue: Int
    var baseRent: Int
    var constructionCost: Int
    var rentByConstructionLevel: [Int]
    var constructionLevel: Int
    var ownerID: UUID?
    var isMortgaged: Bool

    init(
        id: UUID = UUID(),
        name: String,
        colorGroup: ColorGroup,
        purchasePrice: Int,
        mortgageValue: Int,
        baseRent: Int,
        constructionCost: Int = 50,
        rentByConstructionLevel: [Int]? = nil,
        constructionLevel: Int = 0,
        ownerID: UUID? = nil,
        isMortgaged: Bool = false
    ) {
        self.id = id
        self.name = name
        self.colorGroup = colorGroup
        self.purchasePrice = purchasePrice
        self.mortgageValue = mortgageValue
        self.baseRent = baseRent
        self.constructionCost = constructionCost
        self.rentByConstructionLevel = rentByConstructionLevel ?? [
            baseRent,
            baseRent * 5,
            baseRent * 15,
            baseRent * 35,
            baseRent * 50,
            baseRent * 70
        ]
        self.constructionLevel = constructionLevel
        self.ownerID = ownerID
        self.isMortgaged = isMortgaged
    }
}
