import SwiftUI

struct VKServicesScreen: View {
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
            }
            Section {
                Text("Навигационные placeholder-строки: агент должен заменить их реальными NavigationLink с разрешёнными API-запросами.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Сервисы")
    }
}

struct VKMusicScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(colors: [.black, .indigo, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    VStack(alignment: .leading) {
                        Spacer()
                        Text("Музыка").font(.title.bold()).foregroundStyle(.white)
                        Text("Только при официальном доступе к аудио").font(.subheadline).foregroundStyle(.white.opacity(0.85))
                    }
                    .padding(20)
                }
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                VKEmptyState(symbol: "music.note.list", title: "Музыка пока недоступна", details: "Доступ к библиотеке и воспроизведению должен быть подтверждён VK API и правами на контент. Не используйте закрытые токены.")
                    .frame(height: 260)
            }
            .padding(16)
        }
        .background(VKStyle.groupedCanvas)
        .navigationTitle("Музыка")
    }
}

struct VKPermissionState: View {
    let feature: String
    let explanation: String
    let retry: (() -> Void)?

    var body: some View {
        VStack(spacing: 17) {
            Image(systemName: "lock.shield")
                .font(.system(size: 45))
                .foregroundStyle(VKStyle.accent)
            Text("Нет доступа: \(feature)").font(.title3.bold())
            Text(explanation).font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
            if let retry {
                Button("Повторить проверку", action: retry)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(26)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
