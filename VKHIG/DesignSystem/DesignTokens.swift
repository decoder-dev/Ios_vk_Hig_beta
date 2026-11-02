import SwiftUI
import UIKit

/// Semantic design tokens aligned with `design/tokens.json`.
/// Prefer system dynamic colors so light/dark and accessibility adapt automatically.
enum VKStyle {
    /// Sample accent (#1677F2). Replace with brand asset only after legal/branding review.
    static let accent = Color(red: 0.086, green: 0.463, blue: 0.949)
    static let canvas = Color(uiColor: .systemBackground)
    static let groupedCanvas = Color(uiColor: .systemGroupedBackground)
    static let cell = Color(uiColor: .secondarySystemGroupedBackground)
    static let primaryText = Color(uiColor: .label)
    static let secondaryText = Color(uiColor: .secondaryLabel)
    static let separator = Color(uiColor: .separator)
    static let error = Color(uiColor: .systemRed)

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let small: CGFloat = 10
        static let medium: CGFloat = 14
        static let card: CGFloat = 20
        static let bubble: CGFloat = 20
        static let large: CGFloat = 24
    }

    enum Size {
        static let avatarCompact: CGFloat = 32
        static let avatarList: CGFloat = 48
        static let avatarListLarge: CGFloat = 56
        static let tapTargetMin: CGFloat = 44
        static let contentMargin: CGFloat = 16
    }
}
