# Zikr Adventure

Исходники iOS-приложения, документация и история выпусков.

- `main`: исходная опубликованная версия 1.0.0 в `ZikrAdventure-AppStore/` и инфраструктура проекта.
- `codex/release-1.0.1`: рабочая версия 1.0.1 в `ZikrAdventure-1.0.1/`, ожидающая проверки WKWebView.
- Для последующих выпусков: отдельная ветка, проверки, pull request и согласованное слияние в main. Новые копии папок больше не обязательны.
- Git tag фиксирует исходники версии; публикация в App Store подтверждается отдельно.

## Работа и документация

- [Jira](https://zikr-app.atlassian.net/browse/ZKR)
- [Confluence: обзор](https://zikr-app.atlassian.net/wiki/spaces/SD/pages/229378)
- [Процесс разработки и выпуска](https://zikr-app.atlassian.net/wiki/spaces/SD/pages/196809)
- [Релиз 1.0.1](https://zikr-app.atlassian.net/wiki/spaces/SD/pages/229413)
- Локальные документы: `docs/WORKFLOW.md`, `docs/releases/1.0.1.md`.

Внутренняя документация — на русском, материалы App Store — на английском. Credentials, подписи, локальные файлы Xcode и временные сборки исключены из Git.

## Проверки версии 1.0.1

В ветке выпуска: `node ZikrAdventure-1.0.1/tests/counters.cjs`.
Debug для симулятора и Release для iPhone собирались в Xcode 27.0 без подписи. Проверка поведения на iPhone/WKWebView остаётся открытой; приложение 1.0.1 пока не опубликовано.
