import SwiftUI

/// Services hub — entry routes for friends, communities, photos, video (P0/P1 later).
struct ServicesPlaceholderView: View {
    var body: some View {
        List {
            Section("Сервисы") {
                Label("Видео", systemImage: "play.rectangle")
                Label("Сообщества", systemImage: "person.3")
                Label("Друзья", systemImage: "person.2")
                Label("Фотографии", systemImage: "photo.on.rectangle.angled")
            }
            Section("Дополнительно") {
                Label("Сохранённое", systemImage: "bookmark")
                Label("Уведомления", systemImage: "bell")
                Label("Поиск", systemImage: "magnifyingglass")
            }
            Section {
                Text("Placeholder rows only. Replace with NavigationLink destinations once repositories and scopes exist.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Сервисы")
    }
}

#Preview {
    NavigationStack { ServicesPlaceholderView() }
}
