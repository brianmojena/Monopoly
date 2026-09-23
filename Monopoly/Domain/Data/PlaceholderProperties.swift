import Foundation

// Placeholder test data. Replace these values after validating the physical Ultimate Banking edition.
// Rent tables are defined per property. Level-up costs use the shared percentage table in Property.
enum PlaceholderProperties {
    static let all: [Property] = [
        Property(name: "Mediterranean Avenue", colorGroup: .brown, purchasePrice: 60, mortgageValue: 30, baseRent: 2, rentByConstructionLevel: [2, 10, 30, 90, 160, 250]),
        Property(name: "Baltic Avenue", colorGroup: .brown, purchasePrice: 60, mortgageValue: 30, baseRent: 4, rentByConstructionLevel: [4, 20, 60, 180, 320, 450]),
        Property(name: "Oriental Avenue", colorGroup: .lightBlue, purchasePrice: 100, mortgageValue: 50, baseRent: 6, rentByConstructionLevel: [6, 30, 90, 270, 400, 550]),
        Property(name: "Vermont Avenue", colorGroup: .lightBlue, purchasePrice: 100, mortgageValue: 50, baseRent: 6, rentByConstructionLevel: [6, 30, 90, 270, 400, 550]),
        Property(name: "Connecticut Avenue", colorGroup: .lightBlue, purchasePrice: 120, mortgageValue: 60, baseRent: 8, rentByConstructionLevel: [8, 40, 100, 300, 450, 600]),
        Property(name: "St. Charles Place", colorGroup: .pink, purchasePrice: 140, mortgageValue: 70, baseRent: 10, rentByConstructionLevel: [10, 50, 150, 450, 625, 750]),
        Property(name: "States Avenue", colorGroup: .pink, purchasePrice: 140, mortgageValue: 70, baseRent: 10, rentByConstructionLevel: [10, 50, 150, 450, 625, 750]),
        Property(name: "Virginia Avenue", colorGroup: .pink, purchasePrice: 160, mortgageValue: 80, baseRent: 12, rentByConstructionLevel: [12, 60, 180, 500, 700, 900]),
        Property(name: "St. James Place", colorGroup: .orange, purchasePrice: 180, mortgageValue: 90, baseRent: 14, rentByConstructionLevel: [14, 70, 200, 550, 750, 950]),
        Property(name: "Tennessee Avenue", colorGroup: .orange, purchasePrice: 180, mortgageValue: 90, baseRent: 14, rentByConstructionLevel: [14, 70, 200, 550, 750, 950]),
        Property(name: "New York Avenue", colorGroup: .orange, purchasePrice: 200, mortgageValue: 100, baseRent: 16, rentByConstructionLevel: [16, 80, 220, 600, 800, 1000]),
        Property(name: "Kentucky Avenue", colorGroup: .red, purchasePrice: 220, mortgageValue: 110, baseRent: 18, rentByConstructionLevel: [18, 90, 250, 700, 875, 1050]),
        Property(name: "Indiana Avenue", colorGroup: .red, purchasePrice: 220, mortgageValue: 110, baseRent: 18, rentByConstructionLevel: [18, 90, 250, 700, 875, 1050]),
        Property(name: "Illinois Avenue", colorGroup: .red, purchasePrice: 240, mortgageValue: 120, baseRent: 20, rentByConstructionLevel: [20, 100, 300, 750, 925, 1100]),
        Property(name: "Atlantic Avenue", colorGroup: .yellow, purchasePrice: 260, mortgageValue: 130, baseRent: 22, rentByConstructionLevel: [22, 110, 330, 800, 975, 1150]),
        Property(name: "Ventnor Avenue", colorGroup: .yellow, purchasePrice: 260, mortgageValue: 130, baseRent: 22, rentByConstructionLevel: [22, 110, 330, 800, 975, 1150]),
        Property(name: "Marvin Gardens", colorGroup: .yellow, purchasePrice: 280, mortgageValue: 140, baseRent: 24, rentByConstructionLevel: [24, 120, 360, 850, 1025, 1200]),
        Property(name: "Pacific Avenue", colorGroup: .green, purchasePrice: 300, mortgageValue: 150, baseRent: 26, rentByConstructionLevel: [26, 130, 390, 900, 1100, 1275]),
        Property(name: "North Carolina Avenue", colorGroup: .green, purchasePrice: 300, mortgageValue: 150, baseRent: 26, rentByConstructionLevel: [26, 130, 390, 900, 1100, 1275]),
        Property(name: "Pennsylvania Avenue", colorGroup: .green, purchasePrice: 320, mortgageValue: 160, baseRent: 28, rentByConstructionLevel: [28, 150, 450, 1000, 1200, 1400]),
        Property(name: "Park Place", colorGroup: .darkBlue, purchasePrice: 350, mortgageValue: 175, baseRent: 35, rentByConstructionLevel: [35, 175, 500, 1100, 1300, 1500]),
        Property(name: "Boardwalk", colorGroup: .darkBlue, purchasePrice: 400, mortgageValue: 200, baseRent: 50, rentByConstructionLevel: [50, 200, 600, 1400, 1700, 2000])
    ]
}
