# Полная карта экранов VK Native — **44 отдельных экранных сценария**

**Важно:** `Sxx` — идентификатор сценария для Cursor. P0 означает минимально нужный сквозной сценарий, P1 — расширение; P2 — сложный/опциональный путь. Реализация зависит от API/прав. SVG в `design/wireframes/` — схема компоновки, не production screenshots. Каждый скрин должен поддерживать загрузку, пустое состояние, ошибку, отсутствие сети, отказ прав, светлую/тёмную тему и крупный шрифт — кроме чисто статичных state screen.

## Общие требования к любому экрану

- Header: системный `NavigationStack`; крупный заголовок только для root, компактный для detail.
- Content: системные semantic colors, центрирование/отступы по Apple HIG, отсутствие лишнего стекла в текстовом контенте.
- Controls: SF Symbols + voiceover labels; hit targets >=44pt; уничтожающие действия через confirmationDialog.
- Network: независимые состояния loading/loaded/empty/error/offline/unauthorized/permission, retry.
- Navigation: deep links, back gesture, сохранение tab navigation stack.
- Внешний вид: концептуальные boards / точнее SVG wiring + system SDK behavior, не копировать текстовые артефакты генерации.

## Подробный реестр


### S01 — Запуск / определение сессии [P0]

- **Маршрут:** `app://launch` · **Модуль:** Auth · **Экранный тип:** launch.
- **Задача пользователя:** Правильная развилка signed-in/out.
- **Композиция:** Системная лаконичная onboarding/auth surface, одна выраженная CTA, fallback/terms, безопасные redirects.
- **Кандидат на API (не проверен для текущего app):** `VKID session`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Никаких собственных полей пароля VK или фейкового авторизованного состояния.
- **SVG-эскиз:** `design/wireframes/S01.svg`.


### S02 — Вход через VK ID [P0]

- **Маршрут:** `app://login` · **Модуль:** Auth · **Экранный тип:** login.
- **Задача пользователя:** Защищенный OAuth login / errors.
- **Композиция:** Системная лаконичная onboarding/auth surface, одна выраженная CTA, fallback/terms, безопасные redirects.
- **Кандидат на API (не проверен для текущего app):** `VKID SDK`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Никаких собственных полей пароля VK или фейкового авторизованного состояния.
- **SVG-эскиз:** `design/wireframes/S02.svg`.


### S03 — Онбординг [P1]

- **Маршрут:** `app://onboarding` · **Модуль:** Auth · **Экранный тип:** onboarding.
- **Задача пользователя:** Пояснение основных функций и данных.
- **Композиция:** Системная лаконичная onboarding/auth surface, одна выраженная CTA, fallback/terms, безопасные redirects.
- **Кандидат на API (не проверен для текущего app):** `local`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Никаких собственных полей пароля VK или фейкового авторизованного состояния.
- **SVG-эскиз:** `design/wireframes/S03.svg`.


### S04 — Лента [P0]

- **Маршрут:** `tab://feed` · **Модуль:** Home · **Экранный тип:** feed.
- **Задача пользователя:** Посты, stories entry, ленивая загрузка.
- **Композиция:** Большой navigationTitle, горизонтальные stories only if supported, фильтры, LazyVStack из PostCard с мультимедиа и действиями.
- **Кандидат на API (не проверен для текущего app):** `newsfeed.get?`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Пагинация не пересоздаёт видимые посты и не сбрасывает скролл; медиа не блокирует MainActor.
- **SVG-эскиз:** `design/wireframes/S04.svg`.


### S05 — Детали записи [P0]

- **Маршрут:** `feed/post/:id` · **Модуль:** Home · **Экранный тип:** detail.
- **Задача пользователя:** Media, автор, контент, действия.
- **Композиция:** System sheet, overlay/context menu и обратимая navigation, явные действия, ограничения по правам.
- **Кандидат на API (не проверен для текущего app):** `wall.getById?`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Каждая кнопка определена, dismiss/Cancel работают, у опасных действий есть confirmation.
- **SVG-эскиз:** `design/wireframes/S05.svg`.


### S06 — Комментарии [P0]

- **Маршрут:** `feed/post/:id/comments` · **Модуль:** Home · **Экранный тип:** list.
- **Задача пользователя:** Древовидные комментарии, reply.
- **Композиция:** Large title, `.searchable`/filters where suitable, четкие list rows, leading icon/avatar, secondary metadata, meaningful navigation.
- **Кандидат на API (не проверен для текущего app):** `wall.getComments?`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Пустые/загруженные результаты не перепутаны, дебаунс и отмена старых поисковых запросов.
- **SVG-эскиз:** `design/wireframes/S06.svg`.


### S07 — Создание записи [P1]

- **Маршрут:** `feed/new` · **Модуль:** Home · **Экранный тип:** compose.
- **Задача пользователя:** Composer, файлы, предпросмотр.
- **Композиция:** System sheet, overlay/context menu и обратимая navigation, явные действия, ограничения по правам.
- **Кандидат на API (не проверен для текущего app):** `wall.post?`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Каждая кнопка определена, dismiss/Cancel работают, у опасных действий есть confirmation.
- **SVG-эскиз:** `design/wireframes/S07.svg`.


### S08 — Сообщения / список диалогов [P0]

- **Маршрут:** `tab://messages` · **Модуль:** Messages · **Экранный тип:** inbox.
- **Задача пользователя:** Фильтры, непрочитанные, поиск, пагинация.
- **Композиция:** Список сообщений, устойчивые индексы, group separators, sender states, keyboard-safe composer, контекстные меню и unread marker.
- **Кандидат на API (не проверен для текущего app):** `messages.getConversations?`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Переходы сохраняют прокрутку. Повторное получение страницы не создаёт дубликаты; отправка не имитирует успех.
- **SVG-эскиз:** `design/wireframes/S08.svg`.


### S09 — Личный диалог [P0]

- **Маршрут:** `messages/peer/:id` · **Модуль:** Messages · **Экранный тип:** chat.
- **Задача пользователя:** Надежная переписка, composer, вложения.
- **Композиция:** Список сообщений, устойчивые индексы, group separators, sender states, keyboard-safe composer, контекстные меню и unread marker.
- **Кандидат на API (не проверен для текущего app):** `messages.getHistory / send?`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Переходы сохраняют прокрутку. Повторное получение страницы не создаёт дубликаты; отправка не имитирует успех.
- **SVG-эскиз:** `design/wireframes/S09.svg`.


### S10 — Групповой диалог [P1]

- **Маршрут:** `messages/chat/:id` · **Модуль:** Messages · **Экранный тип:** chat.
- **Задача пользователя:** Участники, группировка, права.
- **Композиция:** Список сообщений, устойчивые индексы, group separators, sender states, keyboard-safe composer, контекстные меню и unread marker.
- **Кандидат на API (не проверен для текущего app):** `messages.getHistory?`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Переходы сохраняют прокрутку. Повторное получение страницы не создаёт дубликаты; отправка не имитирует успех.
- **SVG-эскиз:** `design/wireframes/S10.svg`.


### S11 — Информация о диалоге [P1]

- **Маршрут:** `messages/peer/:id/info` · **Модуль:** Messages · **Экранный тип:** profile.
- **Задача пользователя:** Медиа, уведомления, участники.
- **Композиция:** Cover/hero, аватар, имя, краткое описание, CTA (если доступно), 2–4 лаконичных счетчика, нативные секции и links.
- **Кандидат на API (не проверен для текущего app):** `messages.getConversationsById?`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Высота cover адаптивна; без ложного online/verified статусa; нет пробелов при отсутствии данных.
- **SVG-эскиз:** `design/wireframes/S11.svg`.


### S12 — Панель вложений [P1]

- **Маршрут:** `messages/peer/:id/attach` · **Модуль:** Messages · **Экранный тип:** attachments.
- **Задача пользователя:** Выбор фото/файлов с разрешениями.
- **Композиция:** System sheet, overlay/context menu и обратимая navigation, явные действия, ограничения по правам.
- **Кандидат на API (не проверен для текущего app):** `upload endpoints?`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Каждая кнопка определена, dismiss/Cancel работают, у опасных действий есть confirmation.
- **SVG-эскиз:** `design/wireframes/S12.svg`.


### S13 — Действия с сообщением [P1]

- **Маршрут:** `messages/peer/:id/actions` · **Модуль:** Messages · **Экранный тип:** actions.
- **Задача пользователя:** Copy/Reply/Forward/Delete по правам.
- **Композиция:** System sheet, overlay/context menu и обратимая navigation, явные действия, ограничения по правам.
- **Кандидат на API (не проверен для текущего app):** `messages.edit/delete?`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Каждая кнопка определена, dismiss/Cancel работают, у опасных действий есть confirmation.
- **SVG-эскиз:** `design/wireframes/S13.svg`.


### S14 — Поиск по чату [P1]

- **Маршрут:** `messages/peer/:id/search` · **Модуль:** Messages · **Экранный тип:** search.
- **Задача пользователя:** Найти по переписке.
- **Композиция:** Large title, `.searchable`/filters where suitable, четкие list rows, leading icon/avatar, secondary metadata, meaningful navigation.
- **Кандидат на API (не проверен для текущего app):** `messages.search?`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Пустые/загруженные результаты не перепутаны, дебаунс и отмена старых поисковых запросов.
- **SVG-эскиз:** `design/wireframes/S14.svg`.


### S15 — Профиль пользователя [P0]

- **Маршрут:** `user/:id` · **Модуль:** Social · **Экранный тип:** profile.
- **Задача пользователя:** Аватар, cover, friends, actions.
- **Композиция:** Cover/hero, аватар, имя, краткое описание, CTA (если доступно), 2–4 лаконичных счетчика, нативные секции и links.
- **Кандидат на API (не проверен для текущего app):** `users.get?`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Высота cover адаптивна; без ложного online/verified статусa; нет пробелов при отсутствии данных.
- **SVG-эскиз:** `design/wireframes/S15.svg`.


### S16 — Мой профиль [P0]

- **Маршрут:** `tab://profile` · **Модуль:** Social · **Экранный тип:** profile.
- **Задача пользователя:** Личный контент, меню, переходы.
- **Композиция:** Cover/hero, аватар, имя, краткое описание, CTA (если доступно), 2–4 лаконичных счетчика, нативные секции и links.
- **Кандидат на API (не проверен для текущего app):** `users.get?`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Высота cover адаптивна; без ложного online/verified статусa; нет пробелов при отсутствии данных.
- **SVG-эскиз:** `design/wireframes/S16.svg`.


### S17 — Редактирование профиля [P1]

- **Маршрут:** `profile/edit` · **Модуль:** Social · **Экранный тип:** form.
- **Задача пользователя:** Редактируемые поля при поддержке.
- **Композиция:** System Form/List(.insetGrouped), секции с заголовками, нативные switch/row/chevron, текст состояния и Help.
- **Кандидат на API (не проверен для текущего app):** `account methods?`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Каждый toggle реально меняет persistent preference или отражает верный disabled state.
- **SVG-эскиз:** `design/wireframes/S17.svg`.


### S18 — Друзья [P0]

- **Маршрут:** `profile/friends` · **Модуль:** Social · **Экранный тип:** friends.
- **Задача пользователя:** Список, онлайн, поиск.
- **Композиция:** Large title, `.searchable`/filters where suitable, четкие list rows, leading icon/avatar, secondary metadata, meaningful navigation.
- **Кандидат на API (не проверен для текущего app):** `friends.get?`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Пустые/загруженные результаты не перепутаны, дебаунс и отмена старых поисковых запросов.
- **SVG-эскиз:** `design/wireframes/S18.svg`.


### S19 — Заявки в друзья [P1]

- **Маршрут:** `friends/requests` · **Модуль:** Social · **Экранный тип:** list.
- **Задача пользователя:** Входящие и исходящие requests.
- **Композиция:** Large title, `.searchable`/filters where suitable, четкие list rows, leading icon/avatar, secondary metadata, meaningful navigation.
- **Кандидат на API (не проверен для текущего app):** `friends.getRequests?`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Пустые/загруженные результаты не перепутаны, дебаунс и отмена старых поисковых запросов.
- **SVG-эскиз:** `design/wireframes/S19.svg`.


### S20 — Сообщество [P0]

- **Маршрут:** `community/:id` · **Модуль:** Social · **Экранный тип:** community.
- **Задача пользователя:** Вкладки постов, фото, информация.
- **Композиция:** Cover/hero, аватар, имя, краткое описание, CTA (если доступно), 2–4 лаконичных счетчика, нативные секции и links.
- **Кандидат на API (не проверен для текущего app):** `groups.getById?`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Высота cover адаптивна; без ложного online/verified статусa; нет пробелов при отсутствии данных.
- **SVG-эскиз:** `design/wireframes/S20.svg`.


### S21 — Список сообществ [P1]

- **Маршрут:** `communities` · **Модуль:** Social · **Экранный тип:** list.
- **Задача пользователя:** Листинг подписок/поиск.
- **Композиция:** Large title, `.searchable`/filters where suitable, четкие list rows, leading icon/avatar, secondary metadata, meaningful navigation.
- **Кандидат на API (не проверен для текущего app):** `groups.get?`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Пустые/загруженные результаты не перепутаны, дебаунс и отмена старых поисковых запросов.
- **SVG-эскиз:** `design/wireframes/S21.svg`.


### S22 — Участники сообщества [P1]

- **Маршрут:** `community/:id/members` · **Модуль:** Social · **Экранный тип:** friends.
- **Задача пользователя:** Люди, поиск, права доступа.
- **Композиция:** Large title, `.searchable`/filters where suitable, четкие list rows, leading icon/avatar, secondary metadata, meaningful navigation.
- **Кандидат на API (не проверен для текущего app):** `groups.getMembers?`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Пустые/загруженные результаты не перепутаны, дебаунс и отмена старых поисковых запросов.
- **SVG-эскиз:** `design/wireframes/S22.svg`.


### S23 — Глобальный поиск [P0]

- **Маршрут:** `app://search` · **Модуль:** Explore · **Экранный тип:** search.
- **Задача пользователя:** Результаты людей/сообществ/контента.
- **Композиция:** Large title, `.searchable`/filters where suitable, четкие list rows, leading icon/avatar, secondary metadata, meaningful navigation.
- **Кандидат на API (не проверен для текущего app):** `users.search/groups.search?`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Пустые/загруженные результаты не перепутаны, дебаунс и отмена старых поисковых запросов.
- **SVG-эскиз:** `design/wireframes/S23.svg`.


### S24 — Уведомления [P0]

- **Маршрут:** `app://notifications` · **Модуль:** Explore · **Экранный тип:** notifications.
- **Задача пользователя:** Время, типы, статусы, переходы.
- **Композиция:** Large title, `.searchable`/filters where suitable, четкие list rows, leading icon/avatar, secondary metadata, meaningful navigation.
- **Кандидат на API (не проверен для текущего app):** `notifications.get?`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Пустые/загруженные результаты не перепутаны, дебаунс и отмена старых поисковых запросов.
- **SVG-эскиз:** `design/wireframes/S24.svg`.


### S25 — Сервисы / каталог [P1]

- **Маршрут:** `tab://services` · **Модуль:** Explore · **Экранный тип:** services.
- **Задача пользователя:** Роутинг дополнительных разделов.
- **Композиция:** Large title, `.searchable`/filters where suitable, четкие list rows, leading icon/avatar, secondary metadata, meaningful navigation.
- **Кандидат на API (не проверен для текущего app):** `local`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Пустые/загруженные результаты не перепутаны, дебаунс и отмена старых поисковых запросов.
- **SVG-эскиз:** `design/wireframes/S25.svg`.


### S26 — Фотоальбомы [P1]

- **Маршрут:** `profile/albums` · **Модуль:** Media · **Экранный тип:** grid.
- **Задача пользователя:** Albums/grid/count.
- **Композиция:** Системные адаптивные grid/scroll, изображения downsample/cached, контентные media previews, overlay controls по смыслу.
- **Кандидат на API (не проверен для текущего app):** `photos.getAlbums?`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Не требует лишнего разрешения; не запускает нелегальный stream; не ломается на rotation и background.
- **SVG-эскиз:** `design/wireframes/S26.svg`.


### S27 — Фотографии [P1]

- **Маршрут:** `profile/photos` · **Модуль:** Media · **Экранный тип:** grid.
- **Задача пользователя:** Thumbnail grid, pagination.
- **Композиция:** Системные адаптивные grid/scroll, изображения downsample/cached, контентные media previews, overlay controls по смыслу.
- **Кандидат на API (не проверен для текущего app):** `photos.get?`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Не требует лишнего разрешения; не запускает нелегальный stream; не ломается на rotation и background.
- **SVG-эскиз:** `design/wireframes/S27.svg`.


### S28 — Просмотр фотографии [P1]

- **Маршрут:** `photos/:id` · **Модуль:** Media · **Экранный тип:** photo.
- **Задача пользователя:** Full-screen zoom, share.
- **Композиция:** Системные адаптивные grid/scroll, изображения downsample/cached, контентные media previews, overlay controls по смыслу.
- **Кандидат на API (не проверен для текущего app):** `photos.getById?`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Не требует лишнего разрешения; не запускает нелегальный stream; не ломается на rotation и background.
- **SVG-эскиз:** `design/wireframes/S28.svg`.


### S29 — Видео / лента [P1]

- **Маршрут:** `services/video` · **Модуль:** Media · **Экранный тип:** video.
- **Задача пользователя:** Обложки, фильтры, загрузка.
- **Композиция:** Системные адаптивные grid/scroll, изображения downsample/cached, контентные media previews, overlay controls по смыслу.
- **Кандидат на API (не проверен для текущего app):** `video.get?`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Не требует лишнего разрешения; не запускает нелегальный stream; не ломается на rotation и background.
- **SVG-эскиз:** `design/wireframes/S29.svg`.


### S30 — Видеоплеер [P1]

- **Маршрут:** `video/:id` · **Модуль:** Media · **Экранный тип:** player.
- **Задача пользователя:** AVKit stream при доступе.
- **Композиция:** Системные адаптивные grid/scroll, изображения downsample/cached, контентные media previews, overlay controls по смыслу.
- **Кандидат на API (не проверен для текущего app):** `video rights?`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Не требует лишнего разрешения; не запускает нелегальный stream; не ломается на rotation и background.
- **SVG-эскиз:** `design/wireframes/S30.svg`.


### S31 — Музыка / библиотека [P1]

- **Маршрут:** `tab://music` · **Модуль:** Media · **Экранный тип:** music.
- **Задача пользователя:** Playlist/library + легальный доступ.
- **Композиция:** Системные адаптивные grid/scroll, изображения downsample/cached, контентные media previews, overlay controls по смыслу.
- **Кандидат на API (не проверен для текущего app):** `audio access?`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Не требует лишнего разрешения; не запускает нелегальный stream; не ломается на rotation и background.
- **SVG-эскиз:** `design/wireframes/S31.svg`.


### S32 — Аудиоплеер [P2]

- **Маршрут:** `music/player` · **Модуль:** Media · **Экранный тип:** player.
- **Задача пользователя:** Queue/seek/airplay при легальном stream.
- **Композиция:** Системные адаптивные grid/scroll, изображения downsample/cached, контентные media previews, overlay controls по смыслу.
- **Кандидат на API (не проверен для текущего app):** `audio rights?`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Не требует лишнего разрешения; не запускает нелегальный stream; не ломается на rotation и background.
- **SVG-эскиз:** `design/wireframes/S32.svg`.


### S33 — Плейлист [P2]

- **Маршрут:** `music/playlist/:id` · **Модуль:** Media · **Экранный тип:** list.
- **Задача пользователя:** Tracklist, shuffle/add.
- **Композиция:** Large title, `.searchable`/filters where suitable, четкие list rows, leading icon/avatar, secondary metadata, meaningful navigation.
- **Кандидат на API (не проверен для текущего app):** `audio methods?`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Пустые/загруженные результаты не перепутаны, дебаунс и отмена старых поисковых запросов.
- **SVG-эскиз:** `design/wireframes/S33.svg`.


### S34 — Настройки [P1]

- **Маршрут:** `profile/settings` · **Модуль:** Settings · **Экранный тип:** settings.
- **Задача пользователя:** Grouped settings и переходы.
- **Композиция:** System Form/List(.insetGrouped), секции с заголовками, нативные switch/row/chevron, текст состояния и Help.
- **Кандидат на API (не проверен для текущего app):** `local/VKID`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Каждый toggle реально меняет persistent preference или отражает верный disabled state.
- **SVG-эскиз:** `design/wireframes/S34.svg`.


### S35 — Уведомления: настройки [P1]

- **Маршрут:** `settings/notifications` · **Модуль:** Settings · **Экранный тип:** form.
- **Задача пользователя:** Системные уведомления и preferences.
- **Композиция:** System Form/List(.insetGrouped), секции с заголовками, нативные switch/row/chevron, текст состояния и Help.
- **Кандидат на API (не проверен для текущего app):** `UNUserNotificationCenter`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Каждый toggle реально меняет persistent preference или отражает верный disabled state.
- **SVG-эскиз:** `design/wireframes/S35.svg`.


### S36 — Конфиденциальность [P1]

- **Маршрут:** `settings/privacy` · **Модуль:** Settings · **Экранный тип:** form.
- **Задача пользователя:** Privacy доступная API.
- **Композиция:** System Form/List(.insetGrouped), секции с заголовками, нативные switch/row/chevron, текст состояния и Help.
- **Кандидат на API (не проверен для текущего app):** `account privacy?`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Каждый toggle реально меняет persistent preference или отражает верный disabled state.
- **SVG-эскиз:** `design/wireframes/S36.svg`.


### S37 — Оформление [P1]

- **Маршрут:** `settings/appearance` · **Модуль:** Settings · **Экранный тип:** form.
- **Задача пользователя:** Системная тема, контраст, размер.
- **Композиция:** System Form/List(.insetGrouped), секции с заголовками, нативные switch/row/chevron, текст состояния и Help.
- **Кандидат на API (не проверен для текущего app):** `local`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Каждый toggle реально меняет persistent preference или отражает верный disabled state.
- **SVG-эскиз:** `design/wireframes/S37.svg`.


### S38 — Данные и память [P1]

- **Маршрут:** `settings/storage` · **Модуль:** Settings · **Экранный тип:** form.
- **Задача пользователя:** Cache size/clear, auto-download.
- **Композиция:** System Form/List(.insetGrouped), секции с заголовками, нативные switch/row/chevron, текст состояния и Help.
- **Кандидат на API (не проверен для текущего app):** `local`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Каждый toggle реально меняет persistent preference или отражает верный disabled state.
- **SVG-эскиз:** `design/wireframes/S38.svg`.


### S39 — Аккаунт и безопасность [P1]

- **Маршрут:** `settings/account` · **Модуль:** Settings · **Экранный тип:** form.
- **Задача пользователя:** Session/manage/logout.
- **Композиция:** System Form/List(.insetGrouped), секции с заголовками, нативные switch/row/chevron, текст состояния и Help.
- **Кандидат на API (не проверен для текущего app):** `VKID SDK`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Каждый toggle реально меняет persistent preference или отражает верный disabled state.
- **SVG-эскиз:** `design/wireframes/S39.svg`.


### S40 — Сохранённое [P2]

- **Маршрут:** `profile/bookmarks` · **Модуль:** Extras · **Экранный тип:** list.
- **Задача пользователя:** Saved content по правам.
- **Композиция:** Large title, `.searchable`/filters where suitable, четкие list rows, leading icon/avatar, secondary metadata, meaningful navigation.
- **Кандидат на API (не проверен для текущего app):** `fave.get?`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Пустые/загруженные результаты не перепутаны, дебаунс и отмена старых поисковых запросов.
- **SVG-эскиз:** `design/wireframes/S40.svg`.


### S41 — Истории [P2]

- **Маршрут:** `story/:id` · **Модуль:** Extras · **Экранный тип:** detail.
- **Задача пользователя:** Full-bleed stories only if API.
- **Композиция:** System sheet, overlay/context menu и обратимая navigation, явные действия, ограничения по правам.
- **Кандидат на API (не проверен для текущего app):** `stories?`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Каждая кнопка определена, dismiss/Cancel работают, у опасных действий есть confirmation.
- **SVG-эскиз:** `design/wireframes/S41.svg`.


### S42 — Входящий звонок [P2]

- **Маршрут:** `calls/incoming` · **Модуль:** Extras · **Экранный тип:** actions.
- **Задача пользователя:** Только при доступном SDK.
- **Композиция:** System sheet, overlay/context menu и обратимая navigation, явные действия, ограничения по правам.
- **Кандидат на API (не проверен для текущего app):** `official calling SDK?`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Каждая кнопка определена, dismiss/Cancel работают, у опасных действий есть confirmation.
- **SVG-эскиз:** `design/wireframes/S42.svg`.


### S43 — Экран ошибки/нет сети [P2]

- **Маршрут:** `state/error` · **Модуль:** Extras · **Экранный тип:** error.
- **Задача пользователя:** Retry, offline, auth expired, scope.
- **Композиция:** System sheet, overlay/context menu и обратимая navigation, явные действия, ограничения по правам.
- **Кандидат на API (не проверен для текущего app):** `local`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Каждая кнопка определена, dismiss/Cancel работают, у опасных действий есть confirmation.
- **SVG-эскиз:** `design/wireframes/S43.svg`.


### S44 — Шторка действий [P2]

- **Маршрут:** `state/actions` · **Модуль:** Extras · **Экранный тип:** actions.
- **Задача пользователя:** System confirmation/context menus.
- **Композиция:** System sheet, overlay/context menu и обратимая navigation, явные действия, ограничения по правам.
- **Кандидат на API (не проверен для текущего app):** `local`. Проверить official docs, OAuth scope, auth/permission.
- **Требования к поведению:** tap/long press/navigation, skeleton/empty/error/offline/permission, VoiceOver, Dynamic Type, dark mode, scroll restoration.
- **Приёмка:** Каждая кнопка определена, dismiss/Cancel работают, у опасных действий есть confirmation.
- **SVG-эскиз:** `design/wireframes/S44.svg`.


## Дополнительные рекомендации по ключевым экранам

### S08 inbox

Аватар 48–56pt, основной заголовок headline, нижняя строка preview secondary, timestamp caption справа, unread badge внизу справа. Tap — открыть чат, swipe — system contextual options по доступным backend действиям, search — `.searchable`. Не показывать «прочитано» без server confirmation. Avatar updates lazy.

### S09 conversation

Outgoing bubble с brand accent, incoming bubble с system gray; max width адаптивная до ~75–82% content width, не зашивать фиксированное значение в px. Grouped messages без повторения автора; timestamp под ответом/на группе. Composer pinned через `safeAreaInset`, text editor подстраивается под 1–6 строк, send доступна при непустом тексте. Отправка с `random_id`, pending/failed/retry. Loading older messages не прыгает в конец. LongPress → native menu; VoiceOver «Сообщение от...».

### S04 feed

Top actions search и notifications, segment filter, story tray по доступности API. PostCard: автор/время/комьюнити, контент до развернуть, media 16:9/1:1/portrait auto, footer like/comment/repost/save только при подтверждённых permissions, counts с formatter. У загруженных thumbnails фиксировать aspect-ratio чтобы не менялась высота после загрузки. Отсутствие медиаданных не ломает layout.

### S16 profile

Hero image — if provided, avatar overlay; при длинном имени layout адаптивен. 2 primary actions максимум. Friends/Communities/Photos/Video не запихивать в один горизонтальный набор из 10 иконок. Можно использовать минисетки, но доступность важнее. Нет данных → не показывать «0» как истину, если поле не получено.

### S34 settings

`Form` grouped sections: Account, Privacy, Notifications, Appearance, Data & Storage, About, Sign Out. Системные control semantics. Privacy preferences применять на backend только после подтверждения доступности конкретного settings API. Нет nested disabled кнопок без пояснения.

### S31 music

При отсутствии прав **реальный music player не делать**. Вместо этого представить аккуратный unavailable/permission state, не предлагать извлечение закрытых токенов и не включать demo музыку в продуктивной сборке. При наличии официального разрешения — проверенный AVPlayer stream, background audio only с нужными entitlements и правами.

### S29 video

Artwork с duration marker, title, secondary metadata. Player controls через AVKit с корректной буферизацией, orientation/airplay, stream license. Не маскировать недоступность видео фальшивой кнопкой play.
