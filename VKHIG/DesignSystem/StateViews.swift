import SwiftUI

struct LoadableContainer<Value: Equatable, Content: View>: View {
    let state: LoadState<Value>
    let titleForEmpty: String
    let emptySymbol: String
    let emptyDetails: String
    let onRetry: (() -> Void)?
    @ViewBuilder var content: (Value) -> Content

    var body: some View {
        switch state {
        case .idle, .loading:
            VKLoadingState(title: "Loading…")
        case .loaded(let value):
            content(value)
        case .empty:
            VKEmptyState(symbol: emptySymbol, title: titleForEmpty, details: emptyDetails)
        case .failed(let error):
            VKErrorState(message: error.localizedDescription, onRetry: onRetry)
        case .offline:
            VKErrorState(
                message: "You appear to be offline. Check the connection and retry.",
                symbol: "wifi.slash",
                onRetry: onRetry
            )
        }
    }
}

struct VKErrorState: View {
    let message: String
    var symbol: String = "exclamationmark.triangle"
    let onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: VKStyle.Spacing.md) {
            Image(systemName: symbol)
                .font(.system(size: 44))
                .foregroundStyle(VKStyle.error)
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, VKStyle.Spacing.lg)
            if let onRetry {
                Button("Retry", action: onRetry)
                    .buttonStyle(.borderedProminent)
                    .tint(VKStyle.accent)
                    .frame(minHeight: VKStyle.Size.tapTargetMin)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(VKStyle.Spacing.md)
    }
}

struct FixtureBanner: View {
    var body: some View {
        Text("Fixture data — not a live VK response")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.orange.gradient, in: Capsule())
            .accessibilityLabel("Fixture data banner")
    }
}
