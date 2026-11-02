# Apple-native Design System — iOS 27

Цель — системное ощущение на **реальном iOS**, а не изображение стеклянных карточек. Точки отсчёта: Apple HIG, Messages, Music, Photos, Settings. Эскизы `design/boards/*.jpg` содержат 16 тематических экранов, SVG — геометрические схемы.

## 1. Tokens

**Структурные значения** (направляющие; автоматически масштабируются, не заменяют layout rules): отступы `4/8/12/16/20/24/32pt`, внутренний контент-margin `16pt` на компактном iPhone, списковая строка min `56-72pt` при обычном Dynamic Type, высота интерактивного hit region **не менее 44pt** (Apple HIG). Аватары `40-56pt` в списках, `28-36pt` в компактном toolbar. Радиусы: компактные controls `10-14pt`, content media `12-18pt`, крупные cards `18-24pt`, bubbles `18-22pt` с аккуратным grouping; все — ориентиры, не «магические» фиксированные значения.

**Color:** `Color.primary`, `.secondary`, `Color(uiColor: .systemBackground)`, `.secondarySystemGroupedBackground`, `.separator` и semantic tints. Брендовый акцент **VK blue** как управляемая пользовательская палитра; использовать его только для действия/выделения, не переписывать системные colors повсюду. Не делать серый текст вручную с opacity 0.3 на стекле. `design/tokens.json` содержит illustrative reference blue + spacing.

**Type:** `.largeTitle` для крупных заголовков, `.title2`/`.headline` для разделов, `.body`/`.subheadline`/`.caption` для контента; `.font(.system(...))` только при реальной необходимости. Динамические стили превосходят постоянные кегли и «скриншотную» верстку. Учитывай кириллицу и длинные строки.

**Material:** iOS 26+ Liquid Glass системно применяется к tab bar, toolbars, sheets, action menus. **Не применять Liquid Glass в content layer** (постах/групповых карточках/сообщениях), кроме важных transient controls. Элементы контента обычно с системными background и, где нужно, `Material`.

**SF Symbols:** `house`, `square.grid.2x2`, `bubble.left.and.bubble.right`, `music.note`, `person.crop.circle`, `magnifyingglass`, `bell`, `chevron.right`, `ellipsis`, `plus`, `paperplane.fill`, `photo`, `video`, `heart`, `bookmark`, `arrowshape.turn.up.right`, `person.2`, `lock.shield`. Проверить названия и availability в установленном SDK.

## 2. Hierarchy и safe area

- Не прятать content за home indicator/keyboard; использовать `safeAreaInset(edge:)` для composer/miniplayer с учётом tab bar behavior.
- TabView сохраняет по одному NavigationStack на вкладку. Большие заголовки в корневых экранах; компактные в глубине.
- Навигация через системный back gesture, не переопределять hard swipe.
- Плавающий системный tab bar, системные sheet detents, `toolbar` и `.searchable`.
- Страницы чата не обязаны показывать нижнюю tab bar, если открыты навигационно как detail; проверять UX в реальной сборке.

## 3. Разделы

| Раздел | Визуальный характер | Правильный компонент |
|---|---|---|
| Лента | белые/темные разделы, media large card | ScrollView + LazyVStack / PostCard |
| Диалоги | iMessage-inspired четкая строка | List + search + avatars/unread badge |
| Чат | readable bubbles, pinned composer | ScrollViewReader/LazyVStack с надёжным скроллом, safeAreaInset |
| Профиль | динамическая cover, аватар, action row | ScrollView + adaptive header |
| Настройки | групповые секции, иконки и chevrons | Form / List(.insetGrouped) |
| Музыка | выразительный artwork, миниплеер | ScrollView + AVKit controls при реальном audio rights |
| Видео | вертикальные карточки preview и полноэкранный player | LazyVStack + AVPlayer layer |
| Фото | нативная плотная галерея | LazyVGrid + zoom viewer, memory-safe thumbnails |
| Поиск | быстрый search field и grouped results | `.searchable` + async debouncing |

## 4. Состояния каждого экрана

- `initial` / skeleton только когда это реально экономит ожидание;
- `loaded` с настоящими данными;
- `empty` + понятная primary action;
- `offline` + локальный кэш + retry;
- `error` + краткая причина + retry;
- `authExpired` + безопасный login prompt;
- `forbidden` (нет scopes/rights) + объяснение;
- `refreshing` без скачка scroll;
- `pagination` без дублей;
- `dark`, `light`, увеличенный Dynamic Type, Reduce Transparency, Reduce Motion.

## 5. Anims / Feedback

Spring только в hover/context transitions, media opening, inline inserts. Без избыточной анимации списков. Haptics — на отправку, важный confirm и контекстные действия, если это ожидаемо. `UIAccessibility.isReduceMotionEnabled`, системные правила. Плавность 60fps по возможности устройства (или адаптация к ProMotion), не обещать benchmark без Instruments.

## 6. Критерии визуальной корректности

Дизайн должен отличаться от Android не только цветом: настоящая крупная системная навигация, ритм текста, группированные settings, корректные search/toolbar/menu, прозрачный навигационный слой, безопасные отступы, жесты back/scroll, читаемость кириллицы. Минимум 2 размера iPhone в simulator + большой текст + dark mode. Все экраны должны быть доступны по UI paths.
