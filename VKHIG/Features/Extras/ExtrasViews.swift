import SwiftUI

/// S40 — bookmarks / saved.
struct BookmarksView: View {
    var body: some View {
        FixtureScreen(
            title: "Сохранённое",
            screenID: "S40",
            emptyTitle: "Nothing saved",
            emptySymbol: "bookmark",
            emptyDetails: "fave.get when scoped.",
            isEmpty: { $0.isEmpty },
            loadValue: { CatalogFixtures.bookmarks }
        ) { items in
            List(items) { item in
                Label {
                    VStack(alignment: .leading) {
                        Text(item.title)
                        Text(item.subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: item.symbol)
                }
            }
        }
    }
}

/// S41 — stories viewer stub.
struct StoryViewerView: View {
    let storyID: Int64
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LinearGradient(colors: [.purple.opacity(0.6), .blue.opacity(0.5)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack {
                HStack {
                    let story = CatalogFixtures.stories.first(where: { $0.id == storyID })
                    VKAvatar(initials: story?.initials ?? "?", size: 36)
                    Text(story?.author ?? "Story")
                        .foregroundStyle(.white)
                        .font(.headline)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                    }
                }
                .padding()
                Spacer()
                Text("S41 · Stories only when official API exists.\nFixture full-bleed shell — not a live story.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding()
                Spacer()
            }
        }
        .navigationBarHidden(true)
    }
}

/// S42 — incoming call stub (no calling SDK).
struct IncomingCallView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            VKAvatar(initials: "АС", size: 96, tint: .green)
            Text("Анастасия").font(.largeTitle.bold())
            Text("S42 · Incoming call UI stub")
                .foregroundStyle(.secondary)
            Text("Official calling SDK not linked. Actions are disabled.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
            HStack(spacing: 48) {
                Button {} label: {
                    Image(systemName: "phone.down.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(Circle().fill(.red))
                }
                .disabled(true)
                .accessibilityLabel("Decline disabled")
                Button {} label: {
                    Image(systemName: "phone.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(Circle().fill(.green))
                }
                .disabled(true)
                .accessibilityLabel("Accept disabled")
            }
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VKStyle.groupedCanvas)
        .navigationTitle("Звонок")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// S43 — error / offline demo.
struct ErrorDemoView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var mode = "error"

    var body: some View {
        VStack {
            Picker("State", selection: $mode) {
                Text("Error").tag("error")
                Text("Offline").tag("offline")
                Text("Empty").tag("empty")
                Text("Permission").tag("permission")
            }
            .pickerStyle(.segmented)
            .padding()

            Group {
                switch mode {
                case "offline":
                    VKErrorState(message: "S43 · Offline", symbol: "wifi.slash", onRetry: {})
                case "empty":
                    VKEmptyState(symbol: "tray", title: "S43 · Empty", details: "Nothing here yet.")
                case "permission":
                    VKUnavailableState(title: "S43 · Permission", details: "Feature needs an official scope grant.")
                default:
                    VKErrorState(message: "S43 · Something went wrong", onRetry: {})
                }
            }
            Toggle("Simulate offline for app", isOn: Binding(
                get: { !env.isNetworkReachable },
                set: { env.isNetworkReachable = !$0 }
            ))
            .padding()
        }
        .navigationTitle("Состояния")
    }
}

/// S44 — confirmation / context menu demo.
struct ActionsDemoView: View {
    @State private var showConfirm = false
    @State private var showSheet = false
    @State private var result = "—"

    var body: some View {
        List {
            Section("S44") {
                Button("confirmationDialog") { showConfirm = true }
                Button("sheet") { showSheet = true }
                Text("Long-press row for contextMenu")
                    .contextMenu {
                        Button("Copy") { result = "Copy" }
                        Button("Share") { result = "Share" }
                        Button("Delete", role: .destructive) { result = "Delete" }
                    }
            }
            Section("Last action") {
                Text(result)
            }
        }
        .navigationTitle("Действия")
        .confirmationDialog("Выберите действие", isPresented: $showConfirm, titleVisibility: .visible) {
            Button("Primary") { result = "Primary" }
            Button("Destructive", role: .destructive) { result = "Destructive" }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showSheet) {
            NavigationStack {
                Text("System sheet content")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showSheet = false }
                        }
                    }
                    .navigationTitle("Sheet")
            }
            .presentationDetents([.medium])
        }
    }
}
