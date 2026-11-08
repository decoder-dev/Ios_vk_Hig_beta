import SwiftUI

/// Avatar from the boards: real VK photo when the API returned one, otherwise initials on a stable tint.
struct VKAvatar: View {
    let initials: String
    var url: URL? = nil
    var size: CGFloat = VKStyle.Size.avatarList
    var tint: Color? = nil
    var isOnline = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let url {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            fallback
                        }
                    }
                } else {
                    fallback
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            if isOnline {
                Circle()
                    .fill(VKStyle.online)
                    .frame(width: max(10, size * 0.24), height: max(10, size * 0.24))
                    .overlay(Circle().stroke(VKStyle.canvas, lineWidth: max(2, size * 0.04)))
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isOnline ? "Аватар, в сети" : "Аватар")
    }

    private var fallback: some View {
        Text(initials)
            .font(.system(size: size * 0.36, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background((tint ?? Self.tint(for: initials)).gradient, in: Circle())
    }

    /// Deterministic palette so the same person keeps the same colour across launches.
    static func tint(for seed: String) -> Color {
        let palette: [Color] = [.blue, .indigo, .teal, .orange, .pink, .purple, .mint, .cyan]
        let sum = seed.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        return palette[sum % palette.count]
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
