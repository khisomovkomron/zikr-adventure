# ZKR-65 — проверка 18.11.2026

Устройство: выделенный симулятор Zikr iPhone 17, iOS 27.0. Сборка Debug.

- Unit: 5 OnboardingViewModelTests — PASS.
- UI: testSkipAndExistingUser — PASS; testThreeStepsLanguageAndRelaunchPreserveProgress — PASS; testLanguageThemeAndWebReferenceScreenshots — PASS (целевые прогоны).
- Node: auth, bidi-salawat, counters, l10n-native, map-native, onboarding-native, settings-native, sira-native, zikr-native — PASS.
- Генераторы l10n-from-web, zikr-content-from-web, zikr-map-from-web (--check) — PASS.

Матрица снимков: native-light/dark-{ru,en,uz,tg,kk,ky}-1.png; native-light/dark-ky-2/3.png; web-light/dark-en-1.png. Итоговые снимки тем просмотрены вручную. Веб-оригинал сохраняет старую нижнюю панель; нативный онбординг открыт модально поверх всего приложения. Содержимое и порядок шагов сохранены.

В UI-тестах использовался искусственный счёт 123; подтверждено сохранение после завершения и перезапуска. Фикстуры доступны только в Debug при ZIKR_UITEST_AUTH=guest. Не запускать фикстуры на пользовательских данных.

Команда целевой проверки (из ZikrAdventure-1.0.1):

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project ZikrAdventure.xcodeproj -scheme ZikrAdventure \
  -destination 'platform=iOS Simulator,name=Zikr iPhone 17' \
  -jobs 2 -parallel-testing-enabled NO \
  -only-testing:ZikrAdventureTests/OnboardingViewModelTests \
  -only-testing:ZikrAdventureUITests/OnboardingScreenUITests
```

Это целевой QA, не полный прогон приложения. На физическом iPhone, с VoiceOver/Dynamic Type и при обновлении установленной App Store-версии проверка ещё требуется. Release-архив и публикация не проверены.
