import SwiftUI

/// S07 — compose post sheet (local draft only; no fake publish success).
struct ComposePostView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var env
    @AppStorage("vkhig.post.draft") private var text = ""
    @State private var sending = false
    @State private var showDiscard = false
    @State private var notice: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Что у вас нового?", text: $text, axis: .vertical)
                        .lineLimit(5...12)
                }
                Section("Вложения") {
                    Text("Для загрузки фото к записи используйте официальный VK до подключения wall upload flow.").font(.footnote)

                }
                if let notice {
                    Section {
                        Text(notice).foregroundStyle(.secondary)
                    }
                }
                Section {
                    Text("Черновик сохраняется на устройстве. Для публикации нужен доступ к стене.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Новая запись")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if text.isEmpty { dismiss() } else { showDiscard = true }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Publish") {
                        Task {
                            guard env.isLiveVKSession else { notice = "Деморежим: запись не опубликована. Черновик сохранён."; return }
                            sending = true; defer { sending = false }
                            if await env.catalog.perform("wall.post", ["message":text]) { text = ""; dismiss() }
                        }
                    }
                    .disabled(sending || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .confirmationDialog("Discard draft?", isPresented: $showDiscard) {
                Button("Удалить черновик", role: .destructive) { text = ""; dismiss() }
                Button("Keep editing", role: .cancel) {}
            }
        }
    }
}
