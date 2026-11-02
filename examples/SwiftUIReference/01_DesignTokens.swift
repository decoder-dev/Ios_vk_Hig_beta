import SwiftUI

/// Reference tokens: semantic UIKit colors win over manually frozen RGBA values.
enum VKStyle {
    static let accent = Color(red: 0.086, green: 0.463, blue: 0.949) // sample accent
    static let canvas = Color(uiColor: .systemBackground)
    static let groupedCanvas = Color(uiColor: .systemGroupedBackground)
    static let cell = Color(uiColor: .secondarySystemGroupedBackground)
    static let secondaryText = Color(uiColor: .secondaryLabel)
    static let separator = Color(uiColor: .separator)

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
    }
    enum Radius {
        static let card: CGFloat = 18
        static let bubble: CGFloat = 20
    }
}

struct VKAvatar: View {
    let initials: String
    var size: CGFloat = 48
    var tint: Color = .indigo

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.34, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(tint.gradient, in: Circle())
            .accessibilityLabel("Аватар")
    }
}

struct VKLoadingState: View {
    let title: String
    var body: some View {
        ProgressView(title)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
    }
}

struct VKEmptyState: View {
    let symbol: String
    let title: String
    let details: String

    var body: some View {
        ContentUnavailableView(title, systemImage: symbol, description: Text(details))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
