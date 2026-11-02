# Практичный план реализации для Cursor — вертикальные срезы

## Основное правило

Не делать «100 экранов на моках», пока не работает один путь. План — не оценка времени, а порядок зависимости. Каждая фазa заканчивается реальной сборкой или зафиксированным BLOCKED.

### Phase A — baseline + foundation (P0)

- Определить репозиторий, iOS Deployment Target, SDK, target/scheme, существующую архитектуру, доступность Mac/Xcode.
- Исследовать Fenrir/Phoenix (по фактически доступным исходникам) и VK permissions.
- Коммит/ветка baseline; сохранить исходное поведение и test results.
- Ввести цвета, spacing, base controls, root TabView с независимым NavigationStack, auth guard, capability flags.
- Пройти smoke: запуск, навигация, тёмная/светлая тема, oversized text.

### Phase B — communication-first (P0)

- VK ID official sign-in; secure session.
- Inbox list/filter/refresh/pagination.
- Conversation detail/messages with idempotent send + retry + composer.
- Контекстные действия/reply/copy/attachment only if official API.
- Cover errors/offline; Unit tests + UI screenshot + build.

### Phase C — social core (P0)

- Feed cards, post detail, comments if permitted.
- Profile, friends, communities, search + notification entrance.
- Settings screens, theme/system privacy/cache.
- Full P0 regressions with UI tests.

### Phase D — media and secondary (P1)

- Photo grid/viewer, video list/player, attachments.
- Music: UI and licensed source integration **only with official access**; otherwise `UNAVAILABLE` and explicit blocker.
- Community detail, friends requests, bookmarks, profile editor etc. as API permits.

### Phase E — polish (P1/P2)

- Motion, haptics, accessibility, dark, large fonts, RTL safety, long strings, VO navigation.
- Performance instrumentation, regression tests, screenshots for all available routes.
- Release readiness: privacy manifest, permissions, entitlements, crash and logging privacy, App Store and brand compliance.

## Определённые checkpoints

- CP0: baseline test and repo audit output.
- CP1: first launch → tab navigation → fallback offline without crash.
- CP2: sign-in → inbox → conversation → send → server confirm → retry tested.
- CP3: sign-in → feed → post → profile, no fake actions.
- CP4: remaining P0 routes; UI test suite and screenshots.
- CP5: media capabilities clearly recorded; visually polished supported features.

## Когда нужно спросить пользователя

Только при отсутствии основного проекта, Apple signing / developer account, собственного зарегистрированного VK app ID, подтверждения необходимой лицензии или нужного разрешения. Не просить пароли/токены через чат. Не удалять чужой код и не менять backend-contract без согласования; во всех иных случаях двигаться по доступному scope.
