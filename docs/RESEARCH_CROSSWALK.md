# Android → iOS crosswalk: что изучать в Fenrir и что делать в Swift

Эта карта не является заявлением о конкретных классах в репозитории. Указанные названия сущностей — поисковые гипотезы для `rg`, а не проверенные пути в Fenrir.

| Android / Fenrir concept | Что искать в коде | Swift/iOS результат | UX verification |
|---|---|---|---|
| Диалоги | `Dialog`, `Conversation`, `Peer`, `messages.getConversations` | `Conversation`, `InboxRepository`, `InboxScreen` | поиск, unread, paging |
| Чат | `Message`, `Attachments`, `Send`, `LongPoll` | `Message`, `ConversationScreen`, `MessageStore` | отправка/idempotency, gap loading |
| Лента | `Newsfeed`, `Wall`, `Post`, `Repost` | `FeedItem`, `PostCard`, `FeedRepository` | media sizing, comment flow |
| Профиль | `User`, `Profile`, `UserDetails` | `UserProfile`, `ProfileScreen` | counters, actions, privacy |
| Друзья | `Friends`, `Requests`, `Online` | `FriendsScreen`, `FriendRepository` | scope, privacy, filters |
| Сообщества | `Group`, `Community`, `Members` | `CommunityDetail`, `CommunityRepository` | subscribed/permission states |
| Фото | `Photo`, `Album`, `Gallery` | `PhotoGrid`, `PhotoViewer` | thumbnails, zoom, memory |
| Видео | `Video`, `Player`, `Media` | `VideoScreen`, AVKit integration | allowed stream/seek/buffering |
| Музыка | `Audio`, `Playlist`, `Track` | `MusicScreen`, `PlayerCoordinator` | only legal/accessible streams |
| Настройки | `Settings`, `Preferences`, `Account` | `SettingsScreen`, `PreferenceStore` | system themes, cache clear |
| Offline/cache | `Repository`, `Database`, `Cache` | `Repository`, persistence, TTL | stale data messaging |

## Ориентиры публичного дерева Fenrir, проверенные по GitHub root

- `app_fenrir/`: Android application surface, нужна внутренняя ревизия.
- `fenrir_common/`: вероятно общие слои; **гипотеза по названию**, подтвердить при клоне.
- `app_filegallery/`: отдельное приложение FileGallery; README говорит о фото/видео/аудио/тегах.
- `camera2/`, `image/`, `native/`, `material/`, `preference/`, `recyclerview/`: Android-специфичные технические модули; не переносить напрямую.
- Phoenix `app/`, `mvpcore/`: фактические директории корня, inner types подлежат аудиту.

## Результат настоящего аудита должен быть артефактом

`output/REPO_AUDIT.md` должен содержать: hash ветки, список реальных файлов/классов, dependency graph основных feature, network methods, модель данных и UX edge cases, таблицу источников «source path → destination iOS domain type», последствия лицензирования. Без этого нельзя утверждать «исходники прочитаны целиком».
