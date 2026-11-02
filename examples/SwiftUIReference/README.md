# SwiftUI Reference — исходные примеры для адаптации, НЕ production-ready

Это отдельные образцы SwiftUI 17+; не Xcode-проект и не работающая VK-интеграция. Они показывают типы, системные containers и состояния. Для работы в реальном приложении Cursor обязан:

1. Проверить min deployment, compiler, SDK, target `SwiftUI/Observation/Security`.
2. Подключить файлы к существующим targets, устранить имена/сигнатуры и провести build.
3. Заменить `ReferenceFixtures` реальными repositories под разрешённый VK API.
4. Не допустить `Fixture`/fake отправки в production — `MessageComposer` оставляет pending без серверного статуса, пока не подключена real send pipeline.
5. Перепроверить каждое SF Symbol, `.tabBarMinimizeBehavior`, navigation, availability в Xcode.
6. Test code в `examples/Tests` — шаблон, не доказательство выполнения XCTest.

Файлы:

- `01_DesignTokens.swift` — semantic colors/tokens.
- `02_DomainAndFixtures.swift` — domain types + preview data.
- `03_ReferenceRoot.swift` — TabView + per-tab navigation.
- `04_FeedScreen.swift` — лента и карточка.
- `05_InboxScreen.swift` — список диалогов.
- `06_ConversationScreen.swift` — bubbles, composer, pending.
- `07_ProfileAndSettings.swift` — профили и Form.
- `08_MediaAndStates.swift` — media sections + permission/unavailable.
- `09_VKAPIClient.swift` — typed POST transport and error envelope, требует integration review.
- `10_KeychainTokenStore.swift` — пример secure storage API.
- `11_MessageReconciler.swift` — server-ID reconciliation engine для устойчивости.

**Реальные пользовательские данные в примерах отсутствуют.**
