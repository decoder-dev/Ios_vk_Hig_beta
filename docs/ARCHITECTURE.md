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
