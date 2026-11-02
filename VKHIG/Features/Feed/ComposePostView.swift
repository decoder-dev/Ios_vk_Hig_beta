import SwiftUI

/// S07 — compose post sheet (local draft only; no fake publish success).
struct ComposePostView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
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
                    Label("Photo (permissions later)", systemImage: "photo")
                    Label("Video (permissions later)", systemImage: "video")
                }
                if let notice {
                    Section {
                        Text(notice).foregroundStyle(.secondary)
                    }
                }
                Section {
                    Text("Publishing requires verified wall.post scope. Draft stays local.")
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
                        notice = "Not published — live wall.post is gated. Draft kept locally."
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .confirmationDialog("Discard draft?", isPresented: $showDiscard) {
                Button("Discard", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) {}
            }
        }
    }
}
