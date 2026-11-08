# Техническая архитектура iOS приложения

## Рекомендуемые слои (подстроить под существующий репозиторий)

```
App/
  VKNativeApp.swift                # entrypoint, auth state, deep links
  RootCoordinator.swift             # tab selection, per-tab routes
DesignSystem/
  Colors.swift, Spacing.swift, Typography.swift
  Components/{Avatar,LoadState,ErrorView,PostCard,MessageBubble,...}.swift
Features/
  Feed/{FeedScreen,FeedViewModel,FeedRepository}.swift
  Messages/{InboxScreen,ConversationScreen,Composer,MessageRepository}.swift
  Profile/{ProfileScreen,ProfileRepository}.swift
  Friends/, Communities/, Search/, Notifications/, Photos/, Video/, Music/, Settings/
Domain/
  Models/{Peer,Conversation,Message,Post,Attachment,User,Community,...}.swift
  UseCases/{GetInbox,SendMessage,GetFeed,...}.swift
Data/
  VKAPI/{Client,Endpoint,Errors,DTO,Mapper,RateLimit,TokenProvider}.swift
  Cache/{ImageCache,MessageCache,Persistence}.swift
Security/
  VKIDAuthCoordinator.swift, KeychainTokenStore.swift
Tests/
  Unit/, Integration/, UITests/, Fixtures/
```

Структура иллюстративная. Не ломай существующий Workspace ради похожего дерева.

## Domain / UI boundary

- `Network DTO` (nullable, lossy, source-dependent) не попадать напрямую в SwiftUI.
- `Domain` имеет stable identity, optional capabilities, timestamps in UTC и типизированные source IDs.
- `ViewModel` / `Store` владеет loading/pagination/error/send state; UI только display + intents.
- `Repositories` изолируют VK method names и version headers; mock repositories для previews и тестов.
- `CapabilityRegistry` решает enabled/disabled/unsupported для каждого feature на основании официальной API доступности и токена.
- `Navigation` — маршруты, не ad hoc web links. `NavigationStack` per root tab с независимым сохранением state.

## Concurrency

Используй `@MainActor` для изменений UI. Сетевые вызовы асинхронны, поддерживают cancellation, при исчезновении экрана — не «переписывают» новый context. Debounced search; fallback retry с ограниченным backoff только для idempotent requests. Обновление conversation list после отправки без двойного message item.

## Chat reliability

- `peer_id` — стабильный ключ чата, `conversation_message_id`/global message id — различаются; не подменяй один другим.
- Исходящее сообщение получает local temporary ID и `sending` state; отправлять с уникальным `random_id` для idempotency, согласовать затем с серверным ID.
- Дубликаты при retry и paging устранить через stable server message identity.
- Поддержать в UI `sent`, `pending`, `failed`; `delivered/read` **только если поле доступно** и правильно интерпретировано.
- Фото/видео вложения грузить асинхронно и без блокировки main thread; изображения должны downsample по экрану.
- При огромных историях использовать pagination/cursor, не загружать всё в память.

## Cache and privacy

Keychain для credentials. UserDefaults только для non-sensitive UI preferences. Для кэша SQLite/Core Data/SwiftData по фактической потребности. Разработчик должен подтвердить срок жизни и удаление кэша, блокировки при разлогине, удаление чувствительных вложений и токенов, redaction telemetry. Не делать синхронизацию за спиной пользователя без продуктовой причины.

## Разделение демо и production

Fixture mocks можно использовать только в Preview/Test targets. Никаких user-facing «реальных» переписок из сгенерированных данных в релизной сборке.

## Авторизация и мультиаккаунт (`VKHIG/Accounts`)

```
UI: AuthStubView ─▶ AddAccountHubView ─▶ DirectAuthView | WebLoginScreen | TokenEntryView | QRTokenLoginView
                                   │
                                   ▼  addAccount(token…): users.get → Keychain → active
                          AccountManager (CurrentValueSubject accounts / activeAccount)
                           │  KeychainAccountStorage        │ VKAPISession.adapter (token, v, User-Agent)
                           │                                │ onSessionExpired (error 5, payload = token)
                           ▼                                ▼
                   post .vkActiveAccountDidChange ─▶ AppEnvironment.activeAccountDidChange()
                                                      (SessionStore.reconcile, catalog.clear, AudioLibrary reset,
                                                       capabilities + real scopes via account.getAppPermissions)

VKSession (мост): currentUserID / accessToken() / grants
   аккаунт из AccountManager имеет приоритет, иначе — сессия VK ID (VKIDAuthCoordinator, PKCE)
```

- Все чтения «кто вошёл» и «какой токен» идут через `VKSession`; прямых обращений к `VKIDAuthCoordinator.shared.userID` вне `Security/` нет.
- Выход (`AppEnvironment.signOut`) удаляет только активный аккаунт; остальные подхватываются автоматически. Сессия VK ID не затрагивается, пока активен аккаунт.
- Права токенов аккаунта берутся из ответа `account.getAppPermissions`, а не из списка запрошенных; при ошибке запроса список пуст и функции остаются закрытыми.
- LongPoll: в проекте нет постоянного LongPoll-цикла (`messages.getLongPollServer` вызывается из `ConversationViewModel`); он пересоздаётся по смене владельца (`owner`). Новые долгоживущие слушатели должны подписываться на `.vkActiveAccountDidChange`.
- API-версия: собственные запросы `Accounts/` используют `5.131` (по ТЗ), каталог и остальной код — `AppSecrets.vkAPIVersion` (5.199).
