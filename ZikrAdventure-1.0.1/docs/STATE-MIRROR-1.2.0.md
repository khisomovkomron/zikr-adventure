# ZKR-62: надёжность зеркала состояния

План и результаты: https://zikr-app.atlassian.net/wiki/spaces/SD/pages/9371669
Jira: https://zikr-app.atlassian.net/browse/ZKR-62
Версия 1.2.0. Ветка `codex/zkr-62-state-mirror`, [Draft PR #16](https://github.com/khisomovkomron/zikr-adventure/pull/16) в `release/1.2.0`. Статус In Review до iOS QA.

## Решение

- `AppContainer.live()` возвращает один ленивый экземпляр на процесс. Повторный `App.init` получает то же зеркало, что и сохранённый `StateObject`. Preview и явный init остаются изолированными; раннее создание WKWebView не добавлено.
- После ошибки чтения JSONStateStore блокирует автоматическое повторное чтение и запись. Ошибка логируется один раз за жизнь store. Исходный файл не удаляется и не переименовывается.
- `retryUnreadableFile()` разрешает одну попытку по системному сигналу разблокировки либо возвращения в foreground. Контроллер после сигнала снимает актуальный веб-снимок. При успешном восстановлении store публикует прогресс подписчикам даже без нового изменения веба. Здоровый store не перечитывается. Подписки контроллера не удерживают его.
- Replay в `stateMirror.didSet` оставлен и документирован: он нужен для замены/повторного подключения зеркала к уже загруженной странице, хотя штатный старт подключает зеркало раньше.

Веб остаётся единственным писателем. Схема 3, bundle ID, ключи localStorage/progress.json, версия и build не меняются.

## Проверки

`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path ZikrAdventure-1.0.1/Packages/ZikrKit --scratch-path /private/tmp/zikr62-swift --jobs 2`

PASS: 106 XCTest (44 Persistence + 22 Domain + 4 Core + 36 Content), без ошибок. StoreReadErrorTests проверяет сотни обращений без повторного чтения, сохранность байтов, неудачный явный retry и успешное восстановление тем же store. WebStateMirrorTests дополнительно проверяет восстановление очереди и запись свежего снимка. Обновлены прежние ожидания немедленного retry из ZKR-61.

Добавлен iOS-тест identity контейнера/store/зеркала. Его выполнение не подтверждено: первый запуск Xcode прерван после зависания запуска приложения (CoreSimulator сообщил server died), повтор без компиляции остановлен на Resolve Package Graph. Конфигурация .xctestrun не была создана. Финальная Debug-сборка для generic iOS Simulator — BUILD SUCCEEDED (xcodebuild build, -jobs 2, без обновления зависимостей). Эти попытки не считаются успешным iOS QA. Физическая Data Protection/разблокировка, обновление поверх App Store и финальная регрессия ZKR-58 не подтверждены. Недоступность файла до системного сигнала намеренно сохраняется; перезапуск создаёт новую сессию store.
