# Code review guidance / запреты на «красивую, но сломанную» реализацию

Когда Cursor закончит экран, независимо проверяй:

- Бизнес-функция реально работает, а не `Button {}` / только `.preview`.
- Из каждого root tab можно вернуться без потери навигационного стека.
- При смене пользователя нет старого кэша/доступа к чужим диалогам.
- После API `error` не остаётся навсегда spinner и нет подделанного success.
- Backend error / auth expired / missing permission отображается различимо.
- Конкурентные результаты поиска не перезаписывают более свежие результаты.
- `AsyncImage` / thumbnails не инициируют запрос на каждую body recomputation.
- Локальный временный bubble reconcile с server ID без дубликатов.
- Состояния скролла и клавиатуры устойчивы к смене системного размера шрифта.
- Все системные controls остаются VoiceOver-accessible.
- В iOS 27 не применён несуществующий символ/API только по памяти агента.
- В отчёте зафиксирован **запущенный** test command и результат.

Уровни багов: S1 crash/data-loss/credential leak; S2 critical flow impossible; S3 visual/interaction bug; S4 minor polish. S1/S2 = release blocker.
