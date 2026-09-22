import Foundation

// Placeholder test data. Replace these values after validating the physical Ultimate Banking edition.
// Construction cost and rent tables are defined per property; hotel cost uses the same placeholder construction cost as a house.
enum PlaceholderProperties {
    static let all: [Property] = [
        Property(name: "Mediterranean Avenue", colorGroup: .brown, purchasePrice: 60, mortgageValue: 30, baseRent: 2, constructionCost: 50, rentByConstructionLevel: [2, 10, 30, 90, 160, 250]),
        Property(name: "Baltic Avenue", colorGroup: .brown, purchasePrice: 60, mortgageValue: 30, baseRent: 4, constructionCost: 50, rentByConstructionLevel: [4, 20, 60, 180, 320, 450]),
        Property(name: "Oriental Avenue", colorGroup: .lightBlue, purchasePrice: 100, mortgageValue: 50, baseRent: 6, constructionCost: 50, rentByConstructionLevel: [6, 30, 90, 270, 400, 550]),
        Property(name: "Vermont Avenue", colorGroup: .lightBlue, purchasePrice: 100, mortgageValue: 50, baseRent: 6, constructionCost: 50, rentByConstructionLevel: [6, 30, 90, 270, 400, 550]),
        Property(name: "Connecticut Avenue", colorGroup: .lightBlue, purchasePrice: 120, mortgageValue: 60, baseRent: 8, constructionCost: 50, rentByConstructionLevel: [8, 40, 100, 300, 450, 600]),
        Property(name: "St. Charles Place", colorGroup: .pink, purchasePrice: 140, mortgageValue: 70, baseRent: 10, constructionCost: 100, rentByConstructionLevel: [10, 50, 150, 450, 625, 750]),
        Property(name: "States Avenue", colorGroup: .pink, purchasePrice: 140, mortgageValue: 70, baseRent: 10, constructionCost: 100, rentByConstructionLevel: [10, 50, 150, 450, 625, 750]),
        Property(name: "Virginia Avenue", colorGroup: .pink, purchasePrice: 160, mortgageValue: 80, baseRent: 12, constructionCost: 100, rentByConstructionLevel: [12, 60, 180, 500, 700, 900]),
        Property(name: "St. James Place", colorGroup: .orange, purchasePrice: 180, mortgageValue: 90, baseRent: 14, constructionCost: 100, rentByConstructionLevel: [14, 70, 200, 550, 750, 950]),
        Property(name: "Tennessee Avenue", colorGroup: .orange, purchasePrice: 180, mortgageValue: 90, baseRent: 14, constructionCost: 100, rentByConstructionLevel: [14, 70, 200, 550, 750, 950]),
        Property(name: "New York Avenue", colorGroup: .orange, purchasePrice: 200, mortgageValue: 100, baseRent: 16, constructionCost: 100, rentByConstructionLevel: [16, 80, 220, 600, 800, 1000]),
        Property(name: "Kentucky Avenue", colorGroup: .red, purchasePrice: 220, mortgageValue: 110, baseRent: 18, constructionCost: 150, rentByConstructionLevel: [18, 90, 250, 700, 875, 1050]),
        Property(name: "Indiana Avenue", colorGroup: .red, purchasePrice: 220, mortgageValue: 110, baseRent: 18, constructionCost: 150, rentByConstructionLevel: [18, 90, 250, 700, 875, 1050]),
        Property(name: "Illinois Avenue", colorGroup: .red, purchasePrice: 240, mortgageValue: 120, baseRent: 20, constructionCost: 150, rentByConstructionLevel: [20, 100, 300, 750, 925, 1100])
    ]
}
