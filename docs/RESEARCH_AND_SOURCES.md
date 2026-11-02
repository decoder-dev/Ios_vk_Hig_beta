# Исследование: исходники, Apple HIG и статус подтверждения

Дата ревизии публичных источников: **02.11.2026**.

## Репозитории и документация

| Источник | Ссылка | Что подтверждено | Назначение | Статус |
|---|---|---|---|---|
| Fenrir-for-VK | https://github.com/umerov1999/Fenrir-for-VK | Android, Kotlin/C++; от Phoenix; корневые `app_fenrir`, `fenrir_common`, `app_filegallery`, `camera2`, `image`, `native`, `material`, `preference` и др.; GPL-3.0 + ограничивающий README | Изучить функциональность и модели | Проверены README + корневое дерево; глубокий класс-по-классу аудит **не выполнен** |
| Phoenix for VK | https://github.com/PhoenixDevTeam/Phoenix-for-VK | Открытый Android VK-клиент, ветка `kotlin`, корневые `app`, `mvpcore`, GPL-3.0 | Сравнить UX-сценарии, legacy design patterns | Проверены README + корневое дерево; глубокий аудит **не выполнен** |
| Euphoria VK client | https://github.com/euphoriadev/euphoria-vk-client | Android-клиент; README упоминает темы, сообщения, ночную тему; старый проект | Матрица функций как исторический ориентир, не копировать спорные privacy modes | Проверен README |
| VK ID iOS SDK | https://github.com/VKCOM/vkid-ios-sdk | Официальный SDK; README указывает OAuth 2.1 для 2.x и демо | Авторизация и легальный session flow | Проверен README; API доступность уточнить под приложением |
| VKSDK-iOS | https://github.com/VKCOM/VKSDK-iOS | Официальная коллекция SDK; поддерживает SPM | Альтернативная официальная интеграция | Проверен README |
| VK iOS SDK legacy | https://github.com/VKCOM/vk-ios-sdk | Старый SDK / VK API examples | Историческая справка, не копировать древние callbacks без проверки | Проверен README |
| VK PHP SDK | https://github.com/VKCOM/vk-php-sdk | Публичные декларации методов `messages.getConversations`, `getHistory`, `getHistoryAttachments`, `send` и др. | Имена методов как справка, **не** гарантия доступности в iOS-приложении | Просмотрены опубликованные декларации |
| Apple What's new iOS 27 | https://developer.apple.com/ios/whats-new/ | iOS 27 опубликован, новые APIs | Привязка target SDK | Проверен Apple сайт |
| Apple iOS 27 release notes | https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes | SwiftUI/API-изменения, поведение Text selection и AsyncImage caching | Проверить конкретный SDK | Проверен Apple сайт |
| Apple HIG Materials | https://developer.apple.com/design/human-interface-guidelines/materials | Liquid Glass — для интерактивного/навигационного слоя, не контента | Базовое правило материалов | Проверен |
| Apple HIG Tab bars | https://developer.apple.com/design/human-interface-guidelines/tab-bars | Верхнеуровневая навигация, меньше вкладок, плавающий bar | Навигация | Проверен |
| Apple HIG Buttons | https://developer.apple.com/design/human-interface-guidelines/buttons | Чёткие назначения, 44pt hit region, press states | Контролы | Проверен |
| Apple HIG Dark mode | https://developer.apple.com/design/human-interface-guidelines/dark-mode | Системная тёмная схема, контраст, системные dynamic colors | Тема | Проверен |
| WWDC: Build SwiftUI new design | https://developer.apple.com/videos/play/wwdc2025/323/ | Системные API tab bar, sheets, Liquid Glass и toolbar | Техреализация | Проверен |
| Cursor Rules | https://cursor.com/docs/context/rules | Проектные `.cursor/rules/*.mdc`, AGENTS.md | Агентские инструкции | Проверен |

## Выводы и запреты на неверные переносы

1. **Fenrir — не iOS-исходники.** Kotlin/Android View/Fragment/Gradle/Ndk нельзя «перекинуть в Swift» автоматически. Правильно переносить модели данных, правила UX, сценарии и сетевую семантику с собственным Swift-кодом.
2. **Только проверенный scope.** Различай потенциальное наличие метода в SDK, доступность метода по user token конкретного VK-приложения и реальные продуктовые права. Музыка, видео, приватные сообщества и некоторые media методы могут быть недоступны.
3. **Лицензирование.** Fenrir: README прямо ограничивает использование/публикацию, при этом репозиторий показывает GPL-3.0. Phoenix: GPL-3.0. Конфликт/наследование лицензий решать с правообладателем/юристом, не предполагать свободное копирование.
4. **Apple HIG и эскизы.** Изображения в архиве созданы специально как концептуальные визуальные цели, а не взяты из Apple Photos/Messages или VK; они не определяют технический API.
5. **Ограничение фактического аудита.** Из-за ограниченного доступа к вложенным GitHub tree/clone при подготовке пакета были доступны корневые каталоги и README, но **не проводилась полная построчная ревизия Fenrir/Phoenix**. В Cursor должен быть реальный доступ к репозиторию, иначе ставить `SOURCE_NOT_INSPECTED`, а не выдумывать.

## Команды для самостоятельного аудита в Cursor (после проверки GitHub-доступа)

```bash
mkdir -p /tmp/vk-native-research
cd /tmp/vk-native-research
git clone --depth 1 https://github.com/umerov1999/Fenrir-for-VK.git fenrir
git clone --depth 1 https://github.com/PhoenixDevTeam/Phoenix-for-VK.git phoenix
find fenrir/app_fenrir fenrir/fenrir_common -type f | head -150
rg -n -i 'messages|getConversations|newsfeed|friends|wall|audio|video|photo|notifications' fenrir/app_fenrir fenrir/fenrir_common | head -250
```

Не добавляй эти чужие репозитории в commit продукта. Ссылки, путь и хэши исходников записывай в `output/REPO_AUDIT.md`.
