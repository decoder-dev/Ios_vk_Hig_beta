import SwiftUI

/// Building blocks taken from `design/boards/*.jpg`: filter chips, pill segments, stat tiles,
/// settings rows and card surfaces. All colours are semantic so dark mode follows the system.

struct VKChip<Value: Hashable>: Identifiable {
    let value: Value
    let title: String
    var id: Value { value }
}

/// Horizontal filter row ("Все · Личные · Беседы", "Для вас · Друзья · Сообщества").
struct VKChipBar<Value: Hashable>: View {
    let chips: [VKChip<Value>]
    @Binding var selection: Value

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: VKStyle.Spacing.xs) {
                ForEach(chips) { chip in
                    chipButton(chip)
                }
            }
            .padding(.horizontal, VKStyle.Size.contentMargin)
        }
        .scrollClipDisabled()
    }

    private func chipButton(_ chip: VKChip<Value>) -> some View {
        let selected = chip.value == selection
        return Button {
            selection = chip.value
        } label: {
            Text(chip.title)
                .font(.subheadline.weight(selected ? .semibold : .medium))
                .lineLimit(1)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .padding(.horizontal, 14)
                .frame(minHeight: 34)
                .background(selected ? VKStyle.accent : VKStyle.chipFill, in: Capsule())
                .frame(minHeight: VKStyle.Size.tapTargetMin)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Equal-width pills inside one capsule ("Все · Онлайн", "Все фото · Альбомы").
struct VKPillPicker<Value: Hashable>: View {
    let chips: [VKChip<Value>]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 4) {
            ForEach(chips) { chip in
                pill(chip)
            }
        }
        .padding(3)
        .background(VKStyle.chipFill, in: Capsule())
    }

    private func pill(_ chip: VKChip<Value>) -> some View {
        let selected = chip.value == selection
        return Button {
            selection = chip.value
        } label: {
            Text(chip.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(selected ? VKStyle.accent : Color.clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Unread counter. Muted chats use a neutral fill, like the boards.
struct VKBadge: View {
    let count: Int
    var muted = false

    var body: some View {
        Text(count > 999 ? "999+" : count.formatted())
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .frame(minWidth: 20, minHeight: 20)
            .background(muted ? Color(uiColor: .systemGray2) : VKStyle.accent, in: Capsule())
            .accessibilityLabel("Непрочитанных: \(count)")
    }
}

/// Bold section title with an optional "Все ›" action.
struct VKSectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: 2) {
                        Text(actionTitle)
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
                    }
                    .font(.subheadline)
                    .foregroundStyle(VKStyle.accent)
                    .frame(minHeight: VKStyle.Size.tapTargetMin)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, VKStyle.Size.contentMargin)
    }
}

/// Profile counters row tile: symbol, number, caption.
struct VKStatTile: View {
    let symbol: String
    let value: Int?
    let caption: String

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.body.weight(.medium))
                .foregroundStyle(VKStyle.accent)
                .accessibilityHidden(true)
            if let value {
                Text(value.formatted())
                    .font(.headline)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 72)
        .padding(.vertical, 6)
        .background(VKStyle.cell, in: RoundedRectangle(cornerRadius: VKStyle.Radius.tile, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Community action tile ("Записи · Фото · Видео · Участники").
struct VKActionTile: View {
    let symbol: String
    let title: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(VKStyle.accent)
                .accessibilityHidden(true)
            Text(title)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 64)
        .background(VKStyle.cell, in: RoundedRectangle(cornerRadius: VKStyle.Radius.tile, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: VKStyle.Radius.tile, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }
}

/// Settings / profile list row: accent outline symbol, title, optional trailing value.
struct VKIconRow: View {
    let title: String
    let symbol: String
    var value: String? = nil
    var tint: Color = VKStyle.accent

    var body: some View {
        HStack(spacing: VKStyle.Spacing.sm) {
            Image(systemName: symbol)
                .font(.body.weight(.regular))
                .foregroundStyle(tint)
                .frame(width: 28)
                .accessibilityHidden(true)
            Text(title)
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            if let value {
                Text(value)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(minHeight: VKStyle.Size.tapTargetMin)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Inset grouped card surface used outside of `List` (profile, community, feed posts).
struct VKCardModifier: ViewModifier {
    var radius: CGFloat = VKStyle.Radius.card
    func body(content: Content) -> some View {
        content
            .background(VKStyle.cell, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

extension View {
    func vkCard(radius: CGFloat = VKStyle.Radius.card) -> some View {
        modifier(VKCardModifier(radius: radius))
    }
}

/// Neutral cover used when VK returned no cover image. Deterministic per seed.
struct VKCoverBackground: View {
    var url: URL? = nil
    var seed: String = ""

    var body: some View {
        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            if let url {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                }
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }

    private var colors: [Color] {
        let sets: [[Color]] = [
            [Color(red: 0.98, green: 0.62, blue: 0.43), Color(red: 0.42, green: 0.36, blue: 0.75), Color(red: 0.13, green: 0.22, blue: 0.45)],
            [Color(red: 0.36, green: 0.70, blue: 0.92), Color(red: 0.16, green: 0.42, blue: 0.75), Color(red: 0.10, green: 0.18, blue: 0.38)],
            [Color(red: 0.55, green: 0.80, blue: 0.66), Color(red: 0.20, green: 0.52, blue: 0.56), Color(red: 0.10, green: 0.25, blue: 0.33)]
        ]
        let index = seed.unicodeScalars.reduce(0) { ($0 &+ Int($1.value)) & 0xFFFF } % sets.count
        return sets[index]
    }
}

/// Placeholder for media that the demo data references but does not ship.
struct VKMediaPlaceholder: View {
    var symbol = "photo"
    var seed = ""

    var body: some View {
        ZStack {
            VKCoverBackground(seed: seed)
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.white.opacity(0.85))
        }
        .accessibilityHidden(true)
    }
}

/// Full-width tappable row without a disclosure chevron; highlights like a List cell while pressed.
struct VKRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .background(configuration.isPressed ? Color(uiColor: .systemFill) : Color.clear)
    }
}

/// Story avatar with the accent ring from the feed board.
struct VKStoryBubble: View {
    let title: String
    let initials: String
    var url: URL? = nil
    var seen = false

    var body: some View {
        VStack(spacing: 6) {
            VKAvatar(initials: initials, url: url, size: VKStyle.Size.avatarStory - 8)
                .padding(3)
                .overlay(
                    Circle().strokeBorder(
                        seen ? AnyShapeStyle(Color(uiColor: .systemGray3))
                             : AnyShapeStyle(LinearGradient(colors: [VKStyle.accent, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)),
                        lineWidth: 2.5
                    )
                )
            Text(title)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .frame(width: 72)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("История: \(title)")
    }
}

enum VKFormat {
    /// "1,4 тыс." style compact counters for likes, views, members.
    static func compact(_ value: Int) -> String {
        value.formatted(.number.notation(.compactName))
    }

    /// Russian plural: one / few / many.
    static func plural(_ value: Int, _ one: String, _ few: String, _ many: String) -> String {
        let mod10 = value % 10, mod100 = value % 100
        let word: String
        if mod10 == 1 && mod100 != 11 { word = one }
        else if (2...4).contains(mod10) && !(12...14).contains(mod100) { word = few }
        else { word = many }
        return "\(value.formatted()) \(word)"
    }
}
