# ZKR-58 — регрессия нативного runtime 1.2.0

Дата начала: 19.11.2026. Задачи: [ZKR-58](https://zikr-app.atlassian.net/browse/ZKR-58), [ZKR-66](https://zikr-app.atlassian.net/browse/ZKR-66). База — PR #17, 510c163; общий прогон после ZKR-66 (0c25757), затем целевая проверка финальной сборки с ZKR-67.

## Среда и границы

Xcode 27.2, arm64, выделенный iPhone 17/iOS 27.0 simulator «Zikr Migration QA». Одна тяжёлая операция за раз, build -jobs 2, кэш повторно используется. Основной симулятор и опубликованная папка 1.0.0 не меняются. Версия исходников остаётся 1.1.1 (3); загрузки/слияния нет.

Функциональные XCUITest используют DEBUG AuthService: это проверяет UI состояния гостя/аккаунта, но не настоящие Google/Apple, отзыв токена, Keychain или поведение физического iPhone. Все валидные stubs guest/signedIn используют отдельный UITests/zikr-state.json без legacy-import. Тест «Инфо» явно выбирает guest. Обычный запуск не выбирает этот профиль.

## Воспроизводимый функциональный прогон

После build-for-testing использовать соответствующий arm64 .xctestrun и UUID загруженного тестового симулятора:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer caffeinate -i xcodebuild test-without-building \
  -xctestrun "$ZIKR_XCTESTRUN" \
  -destination "platform=iOS Simulator,id=$ZIKR_SIMULATOR_ID" \
  -parallel-testing-enabled NO \
  -only-testing:ZikrAdventureTests -only-testing:ZikrAdventureUITests \
  -skip-testing:ZikrAdventureUITests/ZikrScreenUITests/testScreenshots \
  -skip-testing:ZikrAdventureUITests/SiraScreenUITests/testScreenshots \
  -skip-testing:ZikrAdventureUITests/MapScreenUITests/testScreenshots \
  -skip-testing:ZikrAdventureUITests/SettingsScreenUITests/testScreenshotsAllLanguages \
  -skip-testing:ZikrAdventureUITests/OnboardingScreenUITests/testLanguageThemeScreenshots
```

Матрицы снимков не входят в этот функциональный прогон; их нельзя считать проверенными по наличию функциональных тестов. Уже подтверждённые ранее 124 SwiftPM PASS записаны в NATIVE-COMMANDS-1.2.0.md; они не заменяют app UI/device QA.

## Результаты

| Проверка | Результат |
| --- | --- |
| Общий функциональный прогон до ZKR-67 | 109 app unit/integration + 16 XCUITest PASS одной командой |
| Финальная сборка ZKR-67 | TEST BUILD SUCCEEDED, arm64 |
| Финальные app unit/integration | 112 PASS (включая 29 ZikrViewModel и настоящий same-origin reader) |
| Повторные UI счётчика после ZKR-67 | 3 PASS (tap/undo/reset/history, relaunch, uz labels) |
| Изоляция профиля после signedIn | UITests/zikr-state.json существует и activated=true; обычный zikr-state.json отсутствует, как до тестов |

16 функциональных UI: Инфо — 1, Карта — 3, Онбординг — 2, Настройки — 4, Путь Сиры — 3, Зикр — 3. Проверены карточки/навигация, камера, просмотр глав, пропуск/полные шаги онбординга и сохранение при перезапуске, цель/язык/переключатель, delete/reauth stub, tap/undo/reset/history/relaunch.

Локальные логи: /private/tmp/zikr58-regression-final.log, /private/tmp/zikr67-build.log, /private/tmp/zikr67-final-tests.log. Xcode сохранил .xcresult; после общего прогона было предупреждение сбора диагностик simctl (xcode-select остаётся CLT), при этом тесты завершились TEST EXECUTE SUCCEEDED с кодом 0. Матрицы снимков в этом прогоне не выполнялись.

Найден ZKR-67: при смене дня today оставался вчерашним до ответа следующей команды. Исправление пересчитывает today из текущего daily при показе, foreground, календарном/значимом времени/смене часового пояса, а также до tap/undo. История, total и session не сбрасываются; семантика отмены из ZKR-8 не меняется. Три сценария с управляемым временем прошли в финальном прогоне 112 тестов. Это проверка модели, а не физической полуночи/смены часового пояса на iPhone.

## Открытые критерии выпуска

- Реальный iPhone: Google/Apple вход, выход, удаление, повторный вход и отзыв токена Apple.
- Обновление поверх актуальной опубликованной версии с существующим прогрессом и проверкой миграции.
- Все шесть языков, светлая/тёмная тема, VoiceOver и Dynamic Type на устройстве.
- Итоговая оценка стабильности прогона, размера и запуска, App Privacy/App Store Connect.
- Удаление старых Web/моста только после QA; headless legacy-reader сохраняется для совместимости.
