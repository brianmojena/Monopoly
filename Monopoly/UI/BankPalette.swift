import SwiftUI
#if os(iOS)
import UIKit
#endif

extension Color {
    static let bankGreen = Color(light: (0.08, 0.32, 0.22), dark: (0.12, 0.28, 0.22))
    static let boardGreen = Color(light: (0.1, 0.38, 0.25), dark: (0.18, 0.42, 0.31))
    static let boardRed = Color(light: (0.72, 0.08, 0.11), dark: (0.68, 0.12, 0.15))
    static let boardGold = Color(light: (0.74, 0.49, 0.08), dark: (0.96, 0.72, 0.29))

    private init(light: (Double, Double, Double), dark: (Double, Double, Double)) {
#if os(iOS)
        self.init(UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        })
#else
        self.init(red: light.0, green: light.1, blue: light.2)
#endif
    }
}

extension ColorGroup {
    var swatch: Color {
        switch self {
        case .brown:
            return Color(red: 0.55, green: 0.34, blue: 0.2)
        case .lightBlue:
            return Color(red: 0.55, green: 0.8, blue: 0.95)
        case .pink:
            return Color(red: 0.85, green: 0.3, blue: 0.6)
        case .orange:
            return Color(red: 0.95, green: 0.55, blue: 0.15)
        case .red:
            return Color(red: 0.85, green: 0.15, blue: 0.15)
        case .yellow:
            return Color(red: 0.98, green: 0.82, blue: 0.2)
        case .green:
            return Color(red: 0.15, green: 0.6, blue: 0.3)
        case .darkBlue:
            return Color(red: 0.1, green: 0.25, blue: 0.65)
        }
    }
}

/// A rounded card surface used across the game board.
struct BankCard<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.headline)
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
