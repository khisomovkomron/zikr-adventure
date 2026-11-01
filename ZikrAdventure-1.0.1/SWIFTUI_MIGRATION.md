# SwiftUI Foundation — архитектура (ZKR-47)

Каркас нативного SwiftUI-приложения вокруг существующего WKWebView. Пока все пять экранов остаются веб-экранами; следующие задачи эпика (ZKR-50, 48, 52, 53, 57) могут заменять их по одному.

Рабочий проект: `ZikrAdventure-1.0.1/` (1.1.1, build 3). `ZikrAdventure-AppStore/` не меняется.

## Слои

```
ZikrAdventureApp  (AppContainer.live(): auth, localization, settings, зеркало)
  └─ TabsView
       ├─ ZStack
       │    ├─ WebHostView  →  WebViewManager.shared.viewController  (один WKWebView)
       │    ├─ InfoView      (ZKR-48, поверх веба на вкладке «Инфо»)
       │    └─ SettingsView  (ZKR-50, поверх веба на вкладке «Настройки»)
       └─ NativeTabBar (кастомная нижняя панель, не SwiftUI TabView)
```

Нативный экран показывается по `NativeScreenGate.shouldShowNativeScreen`: флаг включён, данные есть, вкладка выбрана и веб-онбординг точно завершён. Иначе виден веб-экран, как в 1.1.1.

`TabView` здесь не используется: системный фон вкладки непрозрачный и перехватывает нажатия. Web view и tab bar — соседние дети `VStack`, не overlay. Один `UIView` не переносится между иерархиями.

## Единственный контроллер

`WebViewManager` создаёт `WebAppViewController` в `init`. Fallback `WebAppViewController()` в `makeUIViewController` отсутствует.

Порядок инициализации:

1. Первый доступ к `WebViewManager.shared` создаёт менеджер и контроллер, сразу выставляет `controller.webViewManager = self`.
2. `WebHostView.makeUIViewController` забирает тот же контроллер, выставляет `localization` и `authService` (из `AppContainer`), вызывает `auth.activate()` (Firebase уже настроен в `AppDelegate`), регистрирует `tab.change` handler, кладёт стартовый tab в очередь.
3. SwiftUI добавляет контроллер в иерархию → `viewDidLoad` → загрузка `index.html`.
4. `didFinish` → `webViewDidLoad()` сбрасывает очередь `selectTab`.
5. Сообщения `lang.change` / `tab.change` приходят уже на тот же контроллер, у которого есть `localization` и `webViewManager`.

Один `AuthCoordinator` (владелец — `AppContainer.auth`, протокол `AuthService`): его используют и мост `auth.*` веба, и нативный экран «Настройки». Одно JS-состояние.

## Связь native ↔ web

- Native → web: `selectTab(id)` в JS (после загрузки; до загрузки — `pendingSelectTab`).
- Web → native вкладка: `postMessage({ type: "tab.change", tab: id })`.
- Web → native язык: `postMessage({ type: "lang.change", lang, tabs })` → `LocalizationService.setLanguage(code:)` (код в `UserDefaults` "app.language"). Названия вкладок и тексты нативных экранов — из `Localizable.xcstrings`, а не из `tabs`.
- Native → web настройки (ZKR-50): `window.zikrNative.setSetting / setLang / resetDefaults / clearHistory / resetProgress` через `WebSettingsCommandSink` → `WebViewManager.evaluateCommand` (до загрузки страницы команды ждут в очереди). Веб — единственный писатель настроек: применяет команду, сохраняет, шлёт `save`; зеркало пишет `zikr-state.json`, экран получает значение из `SettingsRepository.changes()`.
- Смена языка в вебе ставит `suppressTabChange`, чтобы `selectTab` при перерисовке не дёргал native-вкладку.
- Веб-`#tabbar` скрывается флагом `window.__ZIKR_NATIVE_TABS` (элемент в `index.html` остаётся).

## Файлы каркаса

| Файл | Роль |
|------|------|
| `App/ZikrAdventureApp.swift` | `@main`, Firebase, `TabsView` |
| `App/TabsView.swift` | VStack: web view + NativeTabBar, iOS 16 `onChange(of:)` |
| `App/TabItem.swift` | zikr, map, path, info, settings + SF Symbols |
| `App/WebViewManager.swift` | singleton, eager controller |
| `App/AppContainer.swift` | DI: репозитории, зеркало, `auth`, `localization`, `settingsSink`, фабрики view model, флаги `isNativeInfoEnabled` / `isNativeSettingsEnabled` |
| `App/Localization/` | `LocalizationService` (язык, `tr`, числа в локали языка), `L10nKey` |
| `App/Auth/` | `AuthService`, `AuthCoordinator`, `AccountDeletionFlow` (ZKR-56) |
| `App/Settings/` | `WebSettingsCommandSink`, системные сервисы (Reduce Motion, Safari) |
| `Features/Settings/` | `SettingsView`, `SettingsAccountSection`, `SettingsViewModel`, `SettingsConfirmation` |
| `Resources/Localizable.xcstrings` | генерируется `node tools/l10n-from-web.mjs` из UI в `index.html` + `tools/l10n-native.json`; руками не править |
| `App/WebAppViewController.swift` | WKWebView, мосты, `selectTab` |
| `Web/index.html` | `__ZIKR_NATIVE_TABS`, `tab.change`, `lang.change`, `suppressTabChange`, `window.zikrNative` (ZKR-50) |

Данные уровней в `index.html` не менялись.

## Как позже заменить одну вкладку на native

Оставить `WebViewManager` и контроллер живыми (JS-состояние, auth). Для выбранной вкладки показывать native-view поверх `WebHostView` (в `ZStack`, гейт `NativeScreenGate`), web view не уничтожать. Tab bar остаётся общим. Флаг-выключатель в `AppContainer` возвращает веб-экран без релиза кода.

Тексты: новые ключи добавляются в `UI` в `index.html` (или в `tools/l10n-native.json`, если строка только нативная), затем `node tools/l10n-from-web.mjs` и новый `case` в `L10nKey`. `node tests/l10n-native.cjs` проверяет, что всё синхронно.

## Тесты

- `ZikrKit` — пакетные тесты (домен, хранилище, гейт).
- `ZikrAdventureTests` — unit-тесты приложения: `SettingsViewModel`, `AccountDeletionFlow`, `LocalizationService`.
- `ZikrAdventureUITests` — «Инфо» и «Настройки». `ZIKR_UITEST_AUTH=signedIn|guest` (только DEBUG) подменяет Firebase.
- `tests/*.cjs` — веб (`node tests/<file>.cjs`).

## Ограничения среды, в которой писался код

Xcode в этой среде нет. Сборка, симулятор и жесты на устройстве не запускались. Проверены исходники, pbxproj, `project.yml` и `git diff` против `ba79a3f` для `ZikrAdventure-AppStore/`.
