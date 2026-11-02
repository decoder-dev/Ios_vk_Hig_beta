import SwiftUI

/// S03 — local onboarding explaining core areas.
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0

    private let pages: [(String, String, String)] = [
        ("house.fill", "Лента", "Читайте обновления друзей и сообществ."),
        ("bubble.left.and.bubble.right.fill", "Сообщения", "Надёжные чаты с официальным API, когда scopes доступны."),
        ("person.crop.circle.fill", "Профиль", "Друзья, сообщества, фото и настройки в одном месте.")
    ]

    var body: some View {
        VStack(spacing: VKStyle.Spacing.lg) {
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                    VStack(spacing: VKStyle.Spacing.md) {
                        Image(systemName: item.0)
                            .font(.system(size: 56))
                            .foregroundStyle(VKStyle.accent)
                            .frame(minHeight: 80)
                        Text(item.1).font(.title.bold())
                        Text(item.2)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button(page == pages.count - 1 ? "Готово" : "Далее") {
                if page < pages.count - 1 {
                    page += 1
                } else {
                    dismiss()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(VKStyle.accent)
            .frame(minHeight: VKStyle.Size.tapTargetMin)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(VKStyle.groupedCanvas)
        .navigationTitle("Онбординг")
        .navigationBarTitleDisplayMode(.inline)
    }
}
