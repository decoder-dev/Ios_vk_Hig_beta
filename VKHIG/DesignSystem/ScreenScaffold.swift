import SwiftUI

/// Shared async fixture loader with loading/empty/error/offline surfaces.
@MainActor
@Observable
final class FixtureScreenModel<Value: Equatable> {
    var state: LoadState<Value> = .idle
    var usesFixtures = true

    func load(
        offline: Bool,
        emptyIf: ((Value) -> Bool)? = nil,
        work: () async throws -> Value
    ) async {
        state = .loading
        if offline {
            state = .offline
            return
        }
        do {
            try await Task.sleep(for: .milliseconds(350))
            let value = try await work()
            if let emptyIf, emptyIf(value) {
                state = .empty
            } else {
                state = .loaded(value)
            }
        } catch let error as AppError {
            state = .failed(error)
        } catch {
            state = .failed(.network(error.localizedDescription))
        }
    }
}

struct FixtureScreen<Value: Equatable, Content: View>: View {
    @Environment(AppEnvironment.self) private var env
    @State private var model = FixtureScreenModel<Value>()
    let title: String
    let screenID: String
    let emptyTitle: String
    let emptySymbol: String
    let emptyDetails: String
    let loadValue: () async throws -> Value
    let isEmpty: ((Value) -> Bool)?
    @ViewBuilder var content: (Value) -> Content

    init(
        title: String,
        screenID: String,
        emptyTitle: String,
        emptySymbol: String,
        emptyDetails: String,
        isEmpty: ((Value) -> Bool)? = nil,
        loadValue: @escaping () async throws -> Value,
        @ViewBuilder content: @escaping (Value) -> Content
    ) {
        self.title = title
        self.screenID = screenID
        self.emptyTitle = emptyTitle
        self.emptySymbol = emptySymbol
        self.emptyDetails = emptyDetails
        self.isEmpty = isEmpty
        self.loadValue = loadValue
        self.content = content
    }

    var body: some View {
        LoadableContainer(
            state: model.state,
            titleForEmpty: emptyTitle,
            emptySymbol: emptySymbol,
            emptyDetails: emptyDetails,
            onRetry: { Task { await reload() } }
        ) { value in
            content(value)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if model.usesFixtures {
                HStack {
                    FixtureBanner()
                    Spacer()
                    Text(screenID)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(VKStyle.groupedCanvas.opacity(0.95))
            }
        }
        .navigationTitle(title)
        .task { await reload() }
        .refreshable { await reload() }
    }

    private func reload() async {
        await model.load(offline: !env.isNetworkReachable, emptyIf: isEmpty, work: loadValue)
    }
}
