import SwiftUI
#if os(iOS)
import UIKit
#endif

struct PropertyPhotoCredit: Identifiable {
    let propertyName: String
    let caption: String
    let author: String
    let license: String
    let source: URL

    var id: String { propertyName }
}

/// Vintage Atlantic City postcards and photos from Wikimedia Commons, one per street
/// of the English board, bundled in Assets.xcassets/Properties at 750×500.
enum PropertyPhotos {
    static func assetName(for propertyName: String) -> String {
        let slug = propertyName.lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return "property-\(slug)"
    }

    static func hasPhoto(for propertyName: String) -> Bool {
#if os(iOS)
        UIImage(named: assetName(for: propertyName)) != nil
#else
        false
#endif
    }

    static func credit(for propertyName: String) -> PropertyPhotoCredit? {
        credits.first { $0.propertyName == propertyName }
    }

    static let credits: [PropertyPhotoCredit] = [
        PropertyPhotoCredit(
            propertyName: "Mediterranean Avenue",
            caption: "A mile of the Atlantic City boardwalk, Atlantic City, NJ",
            author: "Postal antigua, autor desconocido",
            license: "Dominio público",
            source: URL(string: "https://commons.wikimedia.org/wiki/File:A_mile_of_the_Atlantic_City_boardwalk,_Atlantic_City,_NJ.png")!
        ),
        PropertyPhotoCredit(
            propertyName: "Baltic Avenue",
            caption: "Weekes' Tavern, 1700-1702 Baltic Avenue, Atlantic City, N. J.",
            author: "Boston Public Library, colección Tichnor Brothers",
            license: "CC BY 2.0",
            source: URL(string: "https://commons.wikimedia.org/wiki/File:Weekes%27_Tavern,_1700-1702_Baltic_Avenue,_Atlantic_City,_N._J._(8405693158).jpg")!
        ),
        PropertyPhotoCredit(
            propertyName: "Oriental Avenue",
            caption: "Zel-Mar Hotel, 516 Oriental Avenue, Atlantic City, N.J.",
            author: "Boston Public Library, colección Tichnor Brothers",
            license: "CC BY 2.0",
            source: URL(string: "https://commons.wikimedia.org/wiki/File:Zel-Mar_Hotel,_516_Oriental_Avenue,_Atlantic_City,_N.J._(8392579824).jpg")!
        ),
        PropertyPhotoCredit(
            propertyName: "Vermont Avenue",
            caption: "Absecon Light House, Atlantic City, New Jersey",
            author: "Postal antigua, autor desconocido",
            license: "Dominio público",
            source: URL(string: "https://commons.wikimedia.org/wiki/File:Absecon_Light_House,_Atlantic_City,_New_Jersey.png")!
        ),
        PropertyPhotoCredit(
            propertyName: "Connecticut Avenue",
            caption: "Astor Hotel, Connecticut Avenue near beach, Atlantic City, N. J.",
            author: "Boston Public Library, colección Tichnor Brothers",
            license: "CC BY 2.0",
            source: URL(string: "https://commons.wikimedia.org/wiki/File:Astor_Hotel,_Connecticut_Avenue_near_beach,_Atlantic_City,_N._J._(8404600761).jpg")!
        ),
        PropertyPhotoCredit(
            propertyName: "St. Charles Place",
            caption: "Atlantic City boardwalk, pier and Blenheim Hotel",
            author: "Postal antigua, autor desconocido",
            license: "Dominio público",
            source: URL(string: "https://commons.wikimedia.org/wiki/File:Atlantic_City_boardwalk,_pier_and_Blenheim_Hotel.png")!
        ),
        PropertyPhotoCredit(
            propertyName: "States Avenue",
            caption: "States Villa Hotel, 125 States Avenue, near the boardwalk, Atlantic City, N.J.",
            author: "Boston Public Library, colección Tichnor Brothers",
            license: "CC BY 2.0",
            source: URL(string: "https://commons.wikimedia.org/wiki/File:States_Villa_Hotel,_125_States_Avenue,_near_the_boardwalk,_Atlantic_City,_N.J._(8392576898).jpg")!
        ),
        PropertyPhotoCredit(
            propertyName: "Virginia Avenue",
            caption: "Virginia Avenue from Boardwalk, Atlantic City, New Jersey",
            author: "Postal antigua, autor desconocido",
            license: "Dominio público",
            source: URL(string: "https://commons.wikimedia.org/wiki/File:Virginia_Avenue_from_Boardwalk,_Atlantic_City,_New_Jersey.png")!
        ),
        PropertyPhotoCredit(
            propertyName: "St. James Place",
            caption: "Elwood Hotel, 164 St. James Place, at the beach between New York and Tennessee Avenue, Atlantic City, N.J.",
            author: "Boston Public Library, colección Tichnor Brothers",
            license: "CC BY 2.0",
            source: URL(string: "https://commons.wikimedia.org/wiki/File:Elwood_Hotel,_164_St._James_Place,_at_the_beach_between_New_York_and_Tennessee_Avenue,_Atlantic_City,_N.J._(8391496713).jpg")!
        ),
        PropertyPhotoCredit(
            propertyName: "Tennessee Avenue",
            caption: "Fleetwood Hotel, 152 South Tennessee Avenue, Atlantic City, N.J.",
            author: "Boston Public Library, colección Tichnor Brothers",
            license: "CC BY 2.0",
            source: URL(string: "https://commons.wikimedia.org/wiki/File:Fleetwood_Hotel,_152_South_Tennessee_Avenue,_Atlantic_City,_N.J._(8404585269).jpg")!
        ),
        PropertyPhotoCredit(
            propertyName: "New York Avenue",
            caption: "New Jackson Hotel, New York Avenue at the boardwalk, Atlantic City, N.J.",
            author: "Boston Public Library, colección Tichnor Brothers",
            license: "CC BY 2.0",
            source: URL(string: "https://commons.wikimedia.org/wiki/File:New_Jackson_Hotel,_New_York_Avenue_at_the_boardwalk,_Atlantic_City,_N.J._(8391493415).jpg")!
        ),
        PropertyPhotoCredit(
            propertyName: "Kentucky Avenue",
            caption: "Clifton's Club Harlem, Kentucky Avenue, Atlantic City, New Jersey LOC 24910495577",
            author: "Library of Congress",
            license: "Sin restricciones conocidas",
            source: URL(string: "https://commons.wikimedia.org/wiki/File:Clifton%27s_Club_Harlem,_Kentucky_Avenue,_Atlantic_City,_New_Jersey_LOC_24910495577.jpg")!
        ),
        PropertyPhotoCredit(
            propertyName: "Indiana Avenue",
            caption: "Lido Motel, Indiana Avenue and Absecon, Atlantic City, N.J.",
            author: "Boston Public Library, colección Tichnor Brothers",
            license: "CC BY 2.0",
            source: URL(string: "https://commons.wikimedia.org/wiki/File:Lido_Motel,_Indiana_Avenue_and_Absecon,_Atlantic_City,_N.J._(8405678088).jpg")!
        ),
        PropertyPhotoCredit(
            propertyName: "Illinois Avenue",
            caption: "Kents Midtown Restaurant in Atlantic City, 1700-04 Pacific Avenue -- at Illinois Avenue Corner -- opposite post office",
            author: "Boston Public Library, colección Tichnor Brothers",
            license: "CC BY 2.0",
            source: URL(string: "https://commons.wikimedia.org/wiki/File:Kents_Midtown_Restaurant_in_Atlantic_City,_1700-04_Pacific_Avenue_--_at_Illinois_Avenue_Corner_--_opposite_post_office_(8405692834).jpg")!
        ),
        PropertyPhotoCredit(
            propertyName: "Atlantic Avenue",
            caption: "Atlantic Avenue looking north, Atlantic City, NJ",
            author: "Postal antigua, autor desconocido",
            license: "Dominio público",
            source: URL(string: "https://commons.wikimedia.org/wiki/File:Atlantic_Avenue_looking_north,_Atlantic_City,_NJ.png")!
        ),
        PropertyPhotoCredit(
            propertyName: "Ventnor Avenue",
            caption: "Samy's Restaurant, 3801 Ventnor Avenue, Atlantic City, N. J.",
            author: "Boston Public Library, colección Tichnor Brothers",
            license: "CC BY 2.0",
            source: URL(string: "https://commons.wikimedia.org/wiki/File:Samy%27s_Restaurant,_3801_Ventnor_Avenue,_Atlantic_City,_N._J._(8405693384).jpg")!
        ),
        PropertyPhotoCredit(
            propertyName: "Marvin Gardens",
            caption: "Marvin Gardens, Atlantic City, N. J.",
            author: "Boston Public Library, colección Tichnor Brothers",
            license: "CC BY 2.0",
            source: URL(string: "https://commons.wikimedia.org/wiki/File:Marvin_Gardens,_Atlantic_City,_N._J._(8405683348).jpg")!
        ),
        PropertyPhotoCredit(
            propertyName: "Pacific Avenue",
            caption: "Dichtor's Hotel, 612-616 Pacific Avenue, Atlantic City, N.J.",
            author: "Boston Public Library, colección Tichnor Brothers",
            license: "CC BY 2.0",
            source: URL(string: "https://commons.wikimedia.org/wiki/File:Dichtor%27s_Hotel,_612-616_Pacific_Avenue,_Atlantic_City,_N.J._(8391497209).jpg")!
        ),
        PropertyPhotoCredit(
            propertyName: "North Carolina Avenue",
            caption: "Boardwalk at Chalfonte and Haddon Hall at night, Atlantic City, N. J.",
            author: "Boston Public Library, colección Tichnor Brothers",
            license: "CC BY 2.0",
            source: URL(string: "https://commons.wikimedia.org/wiki/File:Boardwalk_at_Chalfonte_and_Haddon_Hall_at_night,_Atlantic_City,_N._J._(8404598365).jpg")!
        ),
        PropertyPhotoCredit(
            propertyName: "Pennsylvania Avenue",
            caption: "Maples Hotel, 39 South Pennsylvania Avenue, Atlantic City, N.J.",
            author: "Boston Public Library, colección Tichnor Brothers",
            license: "CC BY 2.0",
            source: URL(string: "https://commons.wikimedia.org/wiki/File:Maples_Hotel,_39_South_Pennsylvania_Avenue,_Atlantic_City,_N.J._(8392581978).jpg")!
        ),
        PropertyPhotoCredit(
            propertyName: "Park Place",
            caption: "Boardwalk and Hotel Traymore, Atlantic City, New Jersey",
            author: "Postal antigua, autor desconocido",
            license: "Dominio público",
            source: URL(string: "https://commons.wikimedia.org/wiki/File:Boardwalk_and_Hotel_Traymore,_Atlantic_City,_New_Jersey.png")!
        ),
        PropertyPhotoCredit(
            propertyName: "Boardwalk",
            caption: "Boardwalk at Steel Pier at night, Atlantic City, N. J.",
            author: "Boston Public Library, colección Tichnor Brothers",
            license: "CC BY 2.0",
            source: URL(string: "https://commons.wikimedia.org/wiki/File:Boardwalk_at_Steel_Pier_at_night,_Atlantic_City,_N._J._(8391487361).jpg")!
        )
    ]
}

/// A property's photo, toned down to sit on the dark board; falls back to its color
/// group when there is no photo.
struct PropertyPhotoView: View {
    let property: Property

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [property.colorGroup.swatch.opacity(0.8), Lux.elevated],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if PropertyPhotos.hasPhoto(for: property.name) {
                Image(PropertyPhotos.assetName(for: property.name))
                    .resizable()
                    .scaledToFill()
                    .saturation(0.85)
                    .overlay(Color.black.opacity(0.12))
            } else {
                Image(systemName: "building.2")
                    .font(.app(.title2))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }
}

struct PhotoCreditsView: View {
    var body: some View {
        List {
            Section {
                ForEach(PropertyPhotos.credits) { credit in
                    Link(destination: credit.source) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(credit.propertyName)
                                .font(.app(.subheadline, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text(credit.caption)
                                .font(.app(.caption))
                                .foregroundStyle(.secondary)
                            Text("\(credit.author) · \(credit.license)")
                                .font(.app(.caption2))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } footer: {
                Text("Fotos de Wikimedia Commons, reducidas y recortadas para la app. Las calles del tablero en inglés son las de Atlantic City; donde la calle ya no existe se usa una vista de la zona.")
            }
        }
        .navigationTitle("Créditos de fotos")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }
}
