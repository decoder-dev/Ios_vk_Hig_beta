import SwiftUI

struct VKProfileScreen: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ZStack(alignment: .bottom) {
                    LinearGradient(colors: [.indigo, .blue.opacity(0.65), .mint], startPoint: .top, endPoint: .bottom)
                        .frame(height: 188)
                    VKAvatar(initials: "ИС", size: 90, tint: .blue)
                        .offset(y: 38)
                }
                .padding(.bottom, 40)
                VStack(spacing: 6) {
                    Text("Иван Смирнов").font(.title2.bold())
                    Text("Москва · Профиль для SwiftUI Preview").font(.subheadline).foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    referenceCounter(342, label: "Друзья")
                    referenceCounter(28, label: "Сообщества")
                    referenceCounter(1247, label: "Фото")
                }
                .padding(.horizontal, 16)
                VStack(spacing: 0) {
                    referenceLink("Фотографии", icon: "photo.on.rectangle.angled")
                    referenceLink("Друзья", icon: "person.2")
                    referenceLink("Сообщества", icon: "person.3")
                    NavigationLink {
                        VKSettingsScreen()
                    } label: {
                        Label("Настройки", systemImage: "gearshape")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                    }
                }
                .background(VKStyle.cell, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 28)
        }
        .background(VKStyle.groupedCanvas)
        .navigationTitle("Профиль")
    }

    private func referenceCounter(_ value: Int, label: String) -> some View {
        VStack(spacing: 5) {
            Text(value.formatted()).font(.headline)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(VKStyle.cell, in: RoundedRectangle(cornerRadius: 14))
    }
    private func referenceLink(_ name: String, icon: String) -> some View {
        HStack {
            Label(name, systemImage: icon)
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .padding(16)
    }
}

struct VKSettingsScreen: View {
    @AppStorage("reference.notifications.enabled") private var exampleNotificationsEnabled = false
    @AppStorage("reference.cellular.download") private var exampleCellularDownload = false

    var body: some View {
        Form {
            Section("Аккаунт") {
                Label("Управление сессией", systemImage: "person.crop.circle")
                Label("Конфиденциальность", systemImage: "lock.shield")
            }
            Section("Уведомления") {
                Toggle("Уведомления в приложении (только demo preference)", isOn: $exampleNotificationsEnabled)
            }
            Section("Данные и память") {
                Toggle("Загрузка через мобильную сеть (demo)", isOn: $exampleCellularDownload)
                Label("Управление кэшем", systemImage: "externaldrive")
            }
            Section("Оформление") {
                LabeledContent("Тема", value: "Как в системе")
                LabeledContent("Шрифт", value: "Системный")
            }
            Section {
                Text("Это пример grouped Form. Реальные настройки VK и параметры push подключаются после проверки API и разрешений.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Настройки")
    }
}
