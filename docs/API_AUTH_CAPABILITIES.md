# VK API, VK ID, авторизация и проверка доступности функций

**Не предполагай, что метод существует и разрешён только потому, что он встречается в стороннем клиенте.** Определяются одновременно: (1) документированный метод/SDK, (2) app type + scopes, (3) разрешения аккаунта, (4) серверные условия/версия API/лимиты, (5) требования платформы/контента.

## Auth flow

1. Зарегистрировать собственное приложение через актуальный официальный кабинет VK ID, получить корректные client/app identifiers и редирект URI. Клиентский секрет не должен размещаться в бинарнике, если он предполагается как confidential secret.
2. Использовать поддерживаемый официальный VK ID iOS SDK и OAuth 2.1 + PKCE, если так предусмотрено выбранным типом OAuth клиента. Руководство: https://github.com/VKCOM/vkid-ios-sdk
3. Регистрация URL scheme / associated domains строго по актуальному README и кабинету продукта.
4. Токен и refresh token (если выдан) — только Keychain, минимальные scopes. Never log tokens/passwords/authorization headers.
5. По возвращении из внешней авторизации проверить state, expiry, отмену и ошибки; рефреш делать официальным способом (если поддерживается); при logout очистить токены/сессию/caches.
6. VK ID авторизация **не означает автоматически** доступ к messages, audio или другим защищенным VK API endpoint. Подтверждать отдельно.

## API layer checklist

- `https://api.vk.com/method/<method>` (точный host и API version сверить с текущей официальной документацией). HTTPS; request POST там, где требуется, токен не включать в URL логов.
- Для имен методов ориентиры: `messages.getConversations`, `messages.getHistory`, `messages.send`, `messages.getHistoryAttachments`, `newsfeed.get`, `wall.get`, `users.get`, `friends.get`, `groups.get`, `photos.get`, `video.get`, `notifications.get`. **Имена здесь — гипотезы для проверки, а не обещание разрешённого доступа.**
- Все response DTO от VK могут иметь `response` или `error`; перечислить retryable errors и auth failure отдельно. Любой response validate.
- Пагинация через `offset`/`count` или `start_from` — строго по конкретному endpoint; не смешивать.
- Ограничение запросов — по официальной спецификации и server backoff. Infinite 429 loop недопустим.
- Отправка сообщений с unique `random_id`/идемпотентностью после сверки метода и scope.
- Локальный cache ограничивать размером, сроком и privacy impact. Зафиксировать TTL.
- Файлы и медиа: upload flow и права на использование — отдельно по каждому типу и endpoint.

## Capabilities (стартовое предположение; Cursor обязан перепроверить)

| Feature | Candidate APIs / SDK | Начальный статус | Условие в UI |
|---|---|---|---|
| VK ID sign-in | VKID-iOS SDK | REQUIRES_CONFIG | Официальный login flow |
| Get profile | `users.get` | NEEDS_SCOPE_CHECK | Read-only / real error |
| Inbox | `messages.getConversations` | NEEDS_SCOPE_CHECK | Не создавать мок переписки в проде |
| Chat history | `messages.getHistory` | NEEDS_SCOPE_CHECK | Paging + retry |
| Send message | `messages.send` | NEEDS_SCOPE_CHECK | Unique random_id, failure UI |
| Feed | `newsfeed.get`, `wall.get` | NEEDS_SCOPE_CHECK | Read-only if reactions not granted |
| Friends | `friends.get` | NEEDS_SCOPE_CHECK | Cache, privacy flags |
| Groups | `groups.get` | NEEDS_SCOPE_CHECK | Hide/manage permissions |
| Photos | `photos.get` | NEEDS_SCOPE_CHECK | Grid, download rights |
| Video | `video.get` | NEEDS_SCOPE_CHECK | Playback only if URL + rights given |
| Music | VK audio / licensed streams | **UNVERIFIED / MAY BE UNAVAILABLE** | Disable playback without legal access |
| Notifications | `notifications.get` | NEEDS_SCOPE_CHECK | Local availability / permissions |
| Calls | supported official call SDK | **UNVERIFIED** | No fake call UI |
| Stories | supported official API | **UNVERIFIED** | No fake creation |

## Security gates

- Не скрапить browser cookie, private API, extractor / token from other client, undocumented endpoints для обхода VK ограничений.
- Не встраивать сторонние ключи или client secrets из Phoenix/Fenrir README; проекту нужны собственные credentials.
- Не пытаться bypass DRM/подписки или технические ограничения аудио/видео.
- При отсутствии scope показывать честный экран запроса разрешения/объяснение, если VKID SDK поддерживает incremental authorization. Не просить пароль напрямую.

## Запись в `output/API_CAPABILITIES.md`

Каждая строка: ID функции, feature, endpoint, doc URL, SDK version, iOS app type, granted scope, проверенный HTTP result (redacted), state (enabled/blocked/unavailable), ответственный screen, дата проверки.

## Дополнительные способы входа (мультиаккаунт)

Помимо VK ID (OAuth 2.1 + PKCE) поддержаны: password grant (`oauth.vk.com/token`, пресеты Kate/Android/iPhone с 2FA и капчей), implicit-flow в `WKWebView`, ручной токен и QR. Токены хранятся в Keychain (`KeychainAccountStorage`), токен валидируется `users.get` до сохранения, ошибка 5 снимает аккаунт.

**Исключение из правил репозитория:** по решению владельца `VKClientPresets.swift` содержит публичные client_id/client_secret сторонних клиентов (запрет на hardcoded secrets из AGENTS.md на этот файл не распространяется). Пароль и токены не логируются. Реальное поведение VK для этих клиентов (в т. ч. «VK ID капча») не проверялось: NOT RUN.

## Password grant: полные DTO, device_id, trusted_hash, sig

`VKHIG/Accounts/AuthModels.swift` типизирует весь ответ `POST /token` (`VKLoginResponseDTO`) и даёт пять клиентов
(`VKAccountType`: VK Android, Kate Mobile, VK Me, VK iOS, VK Admin) с их `client_id`/`client_secret`/User-Agent.
Сохранённый `VKAccount.accountType` теперь определяет **и** User-Agent, **и** `sig` для всех последующих вызовов
этого токена — раньше терялось, какой клиент выдал токен, и подпись не выставлялась.

- `device_id` (UUID, `UserDefaults`) переживает процесс, чтобы не сбрасывать `trusted_hash`.
- `trusted_hash` хранится отдельно от списка аккаунтов (`TrustedHashStore`, ключ — SHA-256 от `clientId:login`)
  и не удаляется обычным выходом, только явным "забыть устройство" (сейчас такого действия в UI нет).
- 2FA: при `validation_type` отличном от `2fa_sms` в экране кода есть «Отправить код по SMS» (дёргает
  `auth.validatePhone`, затем повторяет вход с `force_sms=1`).
- `sig = MD5("/method/{method}?{sorted params}{secret}")` добавляется в `VKAPISession.call` для любого
  аккаунта, у которого VK вернул `secret` (пароль-грант клиенты). Проверено только синтетическим тестом
  детерминированности хэша — реального ответа VK с `sig`-защищённым методом не было.
- Ошибки 14 (капча) и 17 (валидация) из `VKAPISession.call` теперь могут транзитно повторить запрос через
  `challengeResolver` (`VKChallengeResolving`); без установленного резолвера они как раньше превращаются
  в `VKAuthError`. Резолвер сейчас не подключён ни к одному экрану — только сам Direct Auth обрабатывает
  капчу/валидацию при входе, как раньше.
- QR-подтверждение входа на другом устройстве (`auth.processAuthCode`, action 0/1) — `VKQRLoginService` +
  экран «Подтвердить вход на другом устройстве». Отдельно от уже существующего сканирования QR с готовым токеном.
- VK ID Ecosystem OTP (`EcosystemSendOtpResponse`/`EcosystemCheckOtpResponse`/…) — только DTO в `AuthModels.swift`,
  без сетевого клиента и экрана: пароль/VK ID уже дают вход, отдельный безпарольный OTP-флоу не подключали.

**Явно не реализовано (отказ):** WebView-капча с подменой через `CoreMotion`-сенсоры и JS-мост
(`VKWebAppCaptchaSuccess`), выдающая себя за ручной ввод человека — это обход анти-бот защиты VK, что
запрещено независимо от запроса пользователя.
