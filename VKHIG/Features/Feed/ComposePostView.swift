import SwiftUI
import PhotosUI

/// S07 — compose post sheet (local draft only; no fake publish success).
struct ComposePostView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var env
    @AppStorage("vkhig.post.draft") private var text = ""
    @State private var sending = false
    @State private var photo: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var attachment: String?
    @State private var publishGUID = UUID().uuidString
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
                    PhotosPicker(selection:$photo,matching:.images) { Label(photoData == nil ? "Добавить фотографию" : "Фотография выбрана",systemImage:"photo") }
                    if photoData != nil { Button("Убрать фотографию",role:.destructive) { photo = nil; photoData = nil; attachment = nil } }

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
                    Button("Отмена") {
                        if text.isEmpty { dismiss() } else { showDiscard = true }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Опубликовать") {
                        Task {
                            guard env.isLiveVKSession else { notice = "Деморежим: запись не опубликована. Черновик сохранён."; return }
                            sending = true; defer { sending = false }
                            do {
                                if let photoData, attachment == nil { attachment = try await env.catalog.upload(photoData,photo:true,peerID:0,wall:true) }
                                var parameters = ["message":text,"guid":publishGUID]
                                if let attachment { parameters["attachments"] = attachment }
                                _ = try await env.catalog.request("wall.post",parameters)
                                text = ""; dismiss()
                            } catch { notice = error.localizedDescription }
                        }
                    }
                    .disabled(sending || (text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && photoData == nil))
                }
            }
            .task(id:photo) {
                guard let photo else { return }
                do {
                    guard let data = try await photo.loadTransferable(type:Data.self),data.count <= 20_000_000,
                          let image = UIImage(data:data),let jpeg = image.jpegData(compressionQuality:0.8) else { notice = "Не удалось прочитать фото (лимит 20 МБ)."; return }
                    photoData = jpeg; attachment = nil
                } catch { notice = "Не удалось открыть фотографию." }
            }
            .confirmationDialog("Удалить черновик?", isPresented: $showDiscard) {
                Button("Удалить черновик", role: .destructive) { text = ""; dismiss() }
                Button("Продолжить редактирование", role: .cancel) {}
            }
        }
    }
}
