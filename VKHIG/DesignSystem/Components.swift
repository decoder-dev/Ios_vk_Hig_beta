import SwiftUI

struct VKAvatar: View {
    let initials: String
    var size: CGFloat = VKStyle.Size.avatarList
    var tint: Color = .indigo

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.34, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(tint.gradient, in: Circle())
            .accessibilityLabel("Avatar")
    }
}

struct VKLoadingState: View {
    let title: String

    var body: some View {
        ProgressView(title)
            .controlSize(.large)
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

/// Honest unavailable / not-yet-wired feature surface. Never claim live API success.
struct VKUnavailableState: View {
    let title: String
    let details: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "lock.shield")
        } description: {
            Text(details)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(VKStyle.Spacing.md)
    }
}
