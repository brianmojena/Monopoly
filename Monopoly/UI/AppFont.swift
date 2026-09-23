import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Inter, bundled in Fonts/ (Latin subset, SIL Open Font License), replaces the system
/// font across the app; it keeps Dynamic Type by scaling relative to each text style.
enum AppFont {
    static func name(for weight: Font.Weight) -> String {
        switch weight {
        case .black:
            return "Inter-Black"
        case .heavy:
            return "Inter-ExtraBold"
        case .bold:
            return "Inter-Bold"
        case .semibold:
            return "Inter-SemiBold"
        case .medium:
            return "Inter-Medium"
        default:
            return "Inter-Regular"
        }
    }

    // Apple's default sizes at the Large content size.
    static func size(for style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle:
            return 34
        case .title:
            return 28
        case .title2:
            return 22
        case .title3:
            return 20
        case .headline, .body:
            return 17
        case .callout:
            return 16
        case .subheadline:
            return 15
        case .footnote:
            return 13
        case .caption:
            return 12
        case .caption2:
            return 11
        @unknown default:
            return 17
        }
    }

#if os(iOS)
    /// Navigation bars and segmented controls are UIKit and don't read SwiftUI's font.
    static func applyToUIKit() {
        let title = UIFont(name: name(for: .semibold), size: 17) ?? .systemFont(ofSize: 17, weight: .semibold)
        let largeTitle = UIFont(name: name(for: .bold), size: 34) ?? .systemFont(ofSize: 34, weight: .bold)
        UINavigationBar.appearance().titleTextAttributes = [.font: UIFontMetrics(forTextStyle: .headline).scaledFont(for: title)]
        UINavigationBar.appearance().largeTitleTextAttributes = [.font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: largeTitle)]

        let segment = UIFont(name: name(for: .medium), size: 13) ?? .systemFont(ofSize: 13, weight: .medium)
        UISegmentedControl.appearance().setTitleTextAttributes([.font: segment], for: .normal)
    }
#endif
}

extension Font {
    static func app(_ style: Font.TextStyle, weight: Font.Weight? = nil) -> Font {
        let resolvedWeight = weight ?? (style == .headline ? .semibold : .regular)
        return .custom(AppFont.name(for: resolvedWeight), size: AppFont.size(for: style), relativeTo: style)
    }

    static func app(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(AppFont.name(for: weight), size: size)
    }
}
