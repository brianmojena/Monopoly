import Foundation

// Prices and rents of the Monopoly Ultimate Banking edition. Its five printed rent
// levels map to app levels 0...4: a property starts at Ultimate Banking level 1 when
// bought, and each level-up moves it one printed level higher.
// Mortgage values are not part of Ultimate Banking and stay at half the price.
// Level-up costs use the shared percentage table in Property.
enum PlaceholderProperties {
    static let all: [Property] = [
        Property(name: "Mediterranean Avenue", colorGroup: .brown, purchasePrice: 60, mortgageValue: 30, baseRent: 70, rentByConstructionLevel: [70, 130, 220, 370, 750]),
        Property(name: "Baltic Avenue", colorGroup: .brown, purchasePrice: 60, mortgageValue: 30, baseRent: 70, rentByConstructionLevel: [70, 130, 220, 370, 750]),
        Property(name: "Oriental Avenue", colorGroup: .lightBlue, purchasePrice: 100, mortgageValue: 50, baseRent: 80, rentByConstructionLevel: [80, 140, 240, 410, 800]),
        Property(name: "Vermont Avenue", colorGroup: .lightBlue, purchasePrice: 100, mortgageValue: 50, baseRent: 80, rentByConstructionLevel: [80, 140, 240, 410, 800]),
        Property(name: "Connecticut Avenue", colorGroup: .lightBlue, purchasePrice: 120, mortgageValue: 60, baseRent: 100, rentByConstructionLevel: [100, 160, 260, 440, 860]),
        Property(name: "St. Charles Place", colorGroup: .pink, purchasePrice: 140, mortgageValue: 70, baseRent: 110, rentByConstructionLevel: [110, 180, 290, 460, 900]),
        Property(name: "States Avenue", colorGroup: .pink, purchasePrice: 140, mortgageValue: 70, baseRent: 110, rentByConstructionLevel: [110, 180, 290, 460, 900]),
        Property(name: "Virginia Avenue", colorGroup: .pink, purchasePrice: 160, mortgageValue: 80, baseRent: 130, rentByConstructionLevel: [130, 200, 310, 490, 980]),
        Property(name: "St. James Place", colorGroup: .orange, purchasePrice: 180, mortgageValue: 90, baseRent: 140, rentByConstructionLevel: [140, 210, 330, 520, 1000]),
        Property(name: "Tennessee Avenue", colorGroup: .orange, purchasePrice: 180, mortgageValue: 90, baseRent: 140, rentByConstructionLevel: [140, 210, 330, 520, 1000]),
        Property(name: "New York Avenue", colorGroup: .orange, purchasePrice: 200, mortgageValue: 100, baseRent: 160, rentByConstructionLevel: [160, 230, 350, 550, 1100]),
        Property(name: "Kentucky Avenue", colorGroup: .red, purchasePrice: 220, mortgageValue: 110, baseRent: 170, rentByConstructionLevel: [170, 250, 380, 580, 1160]),
        Property(name: "Indiana Avenue", colorGroup: .red, purchasePrice: 220, mortgageValue: 110, baseRent: 170, rentByConstructionLevel: [170, 250, 380, 580, 1160]),
        Property(name: "Illinois Avenue", colorGroup: .red, purchasePrice: 240, mortgageValue: 120, baseRent: 190, rentByConstructionLevel: [190, 270, 400, 610, 1200]),
        Property(name: "Atlantic Avenue", colorGroup: .yellow, purchasePrice: 260, mortgageValue: 130, baseRent: 200, rentByConstructionLevel: [200, 280, 420, 640, 1300]),
        Property(name: "Ventnor Avenue", colorGroup: .yellow, purchasePrice: 260, mortgageValue: 130, baseRent: 200, rentByConstructionLevel: [200, 280, 420, 640, 1300]),
        Property(name: "Marvin Gardens", colorGroup: .yellow, purchasePrice: 280, mortgageValue: 140, baseRent: 220, rentByConstructionLevel: [220, 300, 440, 670, 1340]),
        Property(name: "Pacific Avenue", colorGroup: .green, purchasePrice: 300, mortgageValue: 150, baseRent: 230, rentByConstructionLevel: [230, 320, 460, 700, 1400]),
        Property(name: "North Carolina Avenue", colorGroup: .green, purchasePrice: 300, mortgageValue: 150, baseRent: 230, rentByConstructionLevel: [230, 320, 460, 700, 1400]),
        Property(name: "Pennsylvania Avenue", colorGroup: .green, purchasePrice: 320, mortgageValue: 160, baseRent: 250, rentByConstructionLevel: [250, 340, 480, 730, 1440]),
        Property(name: "Park Place", colorGroup: .darkBlue, purchasePrice: 350, mortgageValue: 175, baseRent: 270, rentByConstructionLevel: [270, 360, 510, 740, 1500]),
        Property(name: "Boardwalk", colorGroup: .darkBlue, purchasePrice: 400, mortgageValue: 200, baseRent: 300, rentByConstructionLevel: [300, 400, 560, 810, 1600])
    ]
}
