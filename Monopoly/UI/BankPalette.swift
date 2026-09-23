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

/// The game board's look: a dark exchange-style surface with a single gold accent,
/// shown the same whatever the system appearance.
enum Lux {
    static let background = Color(red: 0.043, green: 0.055, blue: 0.067)
    static let surface = Color(red: 0.094, green: 0.102, blue: 0.125)
    static let elevated = Color(red: 0.118, green: 0.137, blue: 0.161)
    static let hairline = Color.white.opacity(0.07)
    static let gold = Color(red: 0.941, green: 0.725, blue: 0.043)
    static let champagne = Color(red: 0.843, green: 0.722, blue: 0.451)
    static let textPrimary = Color(red: 0.918, green: 0.925, blue: 0.937)
    static let textSecondary = Color(red: 0.518, green: 0.557, blue: 0.612)
    static let up = Color(red: 0.055, green: 0.796, blue: 0.506)
    static let down = Color(red: 0.965, green: 0.275, blue: 0.365)

    static let goldGradient = LinearGradient(
        colors: [champagne, gold, champagne],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

/// A dark card surface used across the game board.
struct BankCard<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title {
                Text(title.uppercased())
                    .font(.app(.caption, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(Lux.textSecondary)
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Lux.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Lux.hairline, lineWidth: 1)
        }
    }
}
