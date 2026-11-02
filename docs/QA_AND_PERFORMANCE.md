# QA Matrix: баги, производительность, accessibility

## Основные тестовые оси

- Device: маленький iPhone, средний iPhone, большой Pro Max, portrait; landscape, если поддерживается.
- iOS: минимальный deployment target, современный стабильный релиз, iOS 27 при наличии SDK/Simulator.
- Appearance: light, dark; increased contrast, Reduce Transparency.
- Font: default, Large, XXXL Accessibility; русские строки + английские имена + emoji + длинные URL.
- Network: fast, slow 3G emulation, offline at launch, offline during send, 401/403, 429, 500, timeout, broken image.
- Auth: first time, login cancel, expired session, permissions denied, logout, relaunch, multiple account migrations (если поддерживается).
- Data size: 0, 1, 100, 10,000 messages; 0/100 dialogs; long media feed; mixed attachments; duplicate pages.

## P0 E2E acceptance scenarios

| ID | Сценарий | Pass condition |
|---|---|---|
| QA-01 | Cold launch signed-out | Нет краша, понятный login и загрузка |
| QA-02 | OAuth cancel | Сессия не нарушена, понятное состояние |
| QA-03 | OAuth success | Токен в Keychain, загружен профиль/или понятная API ошибка |
| QA-04 | Inbox slow internet | Skeleton/progress, no spinner freeze, retry |
| QA-05 | Inbox pagination | Нет повторных чатов и потери scroll position |
| QA-06 | Chat 5000 chars + emoji | Корректная bubble/selection, без clip |
| QA-07 | Sending + airplane mode | Pending -> failed + retry, нет fake sent |
| QA-08 | Retry same message | Не появляется дублирующее серверное сообщение |
| QA-09 | Keyboard transition | Composer видим, bottom of chat не перекрыт |
| QA-10 | Open photo from chat | Zoom/close, память стабильна |
| QA-11 | Feed scrolling | Плавность, картинки downsample, нет двойных запросов |
| QA-12 | Notification unread | Обновление счётчиков после возвращения из detail |
| QA-13 | Settings theme change | Уважение системной темы и контраста |
| QA-14 | VoiceOver | Все основные действия и контент читаемы с метками |
| QA-15 | Logout | Credentials/cache очистились, возврат в auth state |
| QA-16 | Deep link unknown | Безопасный fallback вместо crash |
| QA-17 | Missing API scope | Честный permission/unavailable state |
| QA-18 | Relaunch into nested tab | Согласованная навигация, нет broken path |

## Автоматизация тестов

- Unit: parsing (nested/unknown fields), stable IDs, DTO→domain mapper, `random_id`, dedup, pagination, error classification, search debounce, capability permissions.
- Integration: URLProtocol stub — 200/4xx/5xx, server `error` envelope, timeouts, replay, cancellation.
- UI: XCUITest happy paths (auth fixture only in tests), screenshots of key screens, accessibility identifiers. Не хранить живой токен в CI.
- Snapshot: reference screenshots generated from real simulator, по каждому экрану + appearance + accessibility; художественные boards — только inspiration.

## Performance targets (цели, не утверждения о достигнутом)

- Нет синхронного parsing/resize на main actor.
- Списки lazy/virtualized; image downsampling и cache; no ever-growing memory use.
- Плавный scroll на целевом устройстве, profiling Instruments для energy/leaks/allocations/hangs.
- Инструментировать launch time, P95 time to first content, stalls >250ms, avg memory for 1000 messages. Baseline + after; число/бюджет утвердить после замера.
- Нет unactionable logs с token/password/личной информацией.

## Обязательный отчёт

`output/TEST_RESULTS.md`: timestamp, OS/SDK/device, command, pass/fail, runtime, log path, before/after screenshot path и unresolved caveats. `NOT RUN` для фактически недоступных инструментов.
