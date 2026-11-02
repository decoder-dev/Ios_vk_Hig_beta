# Agent project instructions — VK Native

- Главная цель: нативный VK iOS client, не просто картинки; идущая от реального repository/API функциональность.
- Прочитай `PROMPT_FOR_CURSOR.md`, `docs/RESEARCH_AND_SOURCES.md`, `docs/DESIGN_SYSTEM.md`, `docs/SCREEN_SPECS.md`, `docs/DEFINITION_OF_DONE.md`.
- Всегда сверяй Apple HIG и SDK availability; не выдумывай методы iOS 27.
- Никогда не копируй Fenrir/Phoenix code/assets без проверки авторских условий; используем эти проекты как functional references.
- Используй существующую архитектуру workspace, если она годится. Новые примеры находятся в `examples/SwiftUIReference`, но они не автоматически production-ready.
- Никаких неофициальных обходов OAuth, извлечения чужих токенов, скрапинга приватных музыкальных API, hardcoded secrets.
- Всегда делай loading/empty/error/retry/permissions/offline states и accessibility.
- После каждой функциональной части запускай реально доступные проверки; всё, что не запускалось, маркируй `NOT RUN`.
- Веди `output/IMPLEMENTATION_STATUS.md`, `output/API_CAPABILITIES.md`, `output/TEST_RESULTS.md`, `output/BLOCKERS.md`.
- Приоритеты: P0 end-to-end > P1 целые фичи > P2 > визуальные эффекты.
