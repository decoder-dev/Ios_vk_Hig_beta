import SwiftUI
import Observation

/// Shared async fixture loader with loading/empty/error/offline surfaces.
@MainActor
@Observable
final class FixtureScreenModel<Value: Equatable> {
    var state: LoadState<Value> = .idle
    var usesFixtures = true
    var pageError: String?
    private var generation=UUID()

    func load(
        offline: Bool,
        preserve:Bool = false,
        emptyIf: ((Value) -> Bool)? = nil,
        work: () async throws -> Value
    ) async {
        generation=UUID();let ticket=generation;pageError=nil
        if !preserve {state = .loading}
        if offline {
            if preserve {pageError="Нет подключения к сети";return}
            state = .offline
            return
        }
        do {
            try await Task.sleep(for: .milliseconds(350))
            let value = try await work()
            try Task.checkCancellation()
            guard ticket==generation else {return}
            if let emptyIf, emptyIf(value) {
                state = .empty
            } else {
                state = .loaded(value)
            }
        } catch is CancellationError {
            return
        } catch let error as AppError {
            guard ticket==generation else {return}
            if preserve {pageError=error.localizedDescription} else {state = .failed(error)}
        } catch {
            guard ticket==generation else {return}
            if preserve {pageError=error.localizedDescription} else {state = .failed(.network(error.localizedDescription))}
        }
    }
}

struct FixtureScreen<Value: Equatable, Content: View>: View {
    @Environment(AppEnvironment.self) private var env
    @State private var model = FixtureScreenModel<Value>()
    @State private var paginating=false
    let title: String
    let resourceID: Int64?
    let query: String
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
        resourceID: Int64? = nil,
        query: String = "",
        emptyTitle: String,
        emptySymbol: String,
        emptyDetails: String,
        isEmpty: ((Value) -> Bool)? = nil,
        loadValue: @escaping () async throws -> Value,
        @ViewBuilder content: @escaping (Value) -> Content
    ) {
        self.resourceID = resourceID
        self.query = query
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
        .safeAreaInset(edge:.bottom) {
            VStack(spacing:4) {
            if let error=model.pageError {Text(error).font(.caption).foregroundStyle(.red)}
            if env.isLiveVKSession,env.catalog.hasMore(screenID,resourceID:resourceID,query:query) {
                Button(paginating ? "Загрузка…" : "Загрузить ещё") {Task {await loadMore()}}.disabled(paginating).frame(minHeight:44).frame(maxWidth:.infinity).background(.regularMaterial)
            }
            }
        }
        .task(id: query) {
            if !query.isEmpty { try? await Task.sleep(for: .milliseconds(300)) }
            guard !Task.isCancelled else { return }
            await reload()
        }
        .refreshable { await reload() }
    }

    private func loadMore() async {
        guard !paginating else {return};paginating=true;defer {paginating=false}
        await model.load(offline:!env.isNetworkReachable,preserve:true,emptyIf:isEmpty) {
            try await env.catalog.load(screenID,resourceID:resourceID,query:query,append:true)
        }
    }
    private func reload() async {
        model.usesFixtures = !env.isLiveVKSession
        await model.load(offline: !env.isNetworkReachable, emptyIf: isEmpty) {
            if env.isLiveVKSession { return try await env.catalog.load(screenID, resourceID: resourceID, query: query) }
            return try await loadValue()
        }
    }
}
