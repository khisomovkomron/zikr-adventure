# SwiftUI Foundation — архитектура (ZKR-47)

Каркас нативного SwiftUI-приложения вокруг существующего WKWebView. Пока все пять экранов остаются веб-экранами; следующие задачи эпика (ZKR-50, 48, 52, 53, 57) могут заменять их по одному.

Рабочий проект: `ZikrAdventure-1.0.1/` (1.1.1, build 3). `ZikrAdventure-AppStore/` не меняется.

## Слои

```
ZikrAdventureApp  (AppContainer.live(): auth, localization, settings, зеркало)
  └─ TabsView
       ├─ ZStack
       │    ├─ WebHostView  →  WebViewManager.shared.viewController  (один WKWebView)
       │    ├─ ZikrView      (ZKR-52, поверх веба на вкладке «Зикр»)
       │    ├─ SiraView      (ZKR-53, поверх веба на вкладке «Путь Сиры»)
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
- Native → web счётчик (ZKR-52): `window.zikrNative.tap / undo / reset("counter"|"all") / clearHistory / explore(id) / snapshot()` через `WebZikrCommandSink`. `tap / undo / reset` выполняют тот же код, что веб-экран (`zikrTap / zikrUndo / zikrReset` в `index.html`: `persist()`, `evaluate()` открывает главы), и возвращают снимок `{ total, today, day, unlocked, fresh, updatedAt }` через `WebViewManager.evaluateQuery`. `ZikrViewModel` показывает нажатие сразу (оптимистично, вибрация и звук 660 Гц — тоже сразу), команды идут по одной (`SerialCommandQueue`: без потерь и перестановок при быстрых нажатиях), ответ веба и `ProgressRepository.changes()` сверяют экран; снимок файла старше подтверждённого `updatedAt` не откатывает счёт. Веб остаётся единственным писателем `total / daily / unlocked`. «Изучить» в баннере вызывает `explore(id)`: веб открывает главу на карте (глава без города — лист на «Пути Сиры»), `tab.change` переключает нативную вкладку. «Сеанс» живёт только в памяти, как `let session` в вебе.
- Native → web «Путь Сиры» (ZKR-53): `window.zikrNative.markViewed(id)` («Читать»: лист главы рисует native, веб пишет `viewed`, как `chapterCard / placeCard`), `showChapter(id)` («На карте» в строке: как `data-go` — `markViewed` + `openCity(city, chapterFocus(ch))`) и `explore(id)` («На карте» в листе) через `WebSiraCommandSink`. Команды принимаются только для открытых глав (`isOpen`, с предпросмотром). Веб остаётся единственным писателем `viewed / city`. Метки «Новое» — по снимку `viewed` при показе вкладки и при смене языка (как `renderPath()` в `selectTab / renderAll`), поэтому после «Читать» метка исчезает при следующем показе вкладки. «Изучить» в баннере «Зикра» для главы без города (ch19) открывает нативный лист на вкладке «Путь Сиры» (веб-лист был бы под нативным экраном); главы с городом — как раньше, карта.
- Смена языка в вебе ставит `suppressTabChange`, чтобы `selectTab` при перерисовке не дёргал native-вкладку.
- Веб-`#tabbar` скрывается флагом `window.__ZIKR_NATIVE_TABS` (элемент в `index.html` остаётся).

## Файлы каркаса

| Файл | Роль |
|------|------|
| `App/ZikrAdventureApp.swift` | `@main`, Firebase, `TabsView` |
| `App/TabsView.swift` | VStack: web view + NativeTabBar, iOS 16 `onChange(of:)` |
| `App/TabItem.swift` | zikr, map, path, info, settings + SF Symbols |
| `App/WebViewManager.swift` | singleton, eager controller |
| `App/AppContainer.swift` | DI: репозитории, зеркало, `auth`, `localization`, `settingsSink`, фабрики view model, флаги `isNativeInfoEnabled` / `isNativeSettingsEnabled` / `isNativeZikrEnabled` / `isNativeSiraEnabled` |
| `App/Localization/` | `LocalizationService` (язык, `tr`, числа в локали языка), `L10nKey` |
| `App/Auth/` | `AuthService`, `AuthCoordinator`, `AccountDeletionFlow` (ZKR-56) |
| `App/Settings/` | `WebSettingsCommandSink`, системные сервисы (Reduce Motion, Safari) |
| `App/Zikr/` | `WebZikrCommandSink`, `SerialCommandQueue`, `ZikrFeedbackService` (вибрация как `vibrate()`, звук `tapSound()` на AVAudioEngine), `VoiceOverAnnouncer` |
| `App/Sira/` | `WebSiraCommandSink` (ZKR-53) |
| `Features/Sira/` | `SiraView` (уровни, лента глав, метка «Новое»), `SiraChapterSheet` (chapterCard / placeCard), `SiraViewModel` |
| `Features/Zikr/` | `ZikrView`, `ZikrTapButton`, `ZikrProgressCard`, `ZikrUnlockBannerView`, `ZikrHistorySheet`, `ZikrViewModel` |
| `ZikrKit/ZikrContent` | `zikr-content.json` (названия уровней, заголовки и годы глав на 6 языках; ZKR-53: город, место, фокус и текст глав, карточки мест глав `PLACES`, расстояния `DIST`, `SAFA_MARWA`) — генерируется `node tools/zikr-content-from-web.mjs` из `index.html` |
| `Features/Settings/` | `SettingsView`, `SettingsAccountSection`, `SettingsViewModel`, `SettingsConfirmation` |
| `Resources/Localizable.xcstrings` | генерируется `node tools/l10n-from-web.mjs` из UI в `index.html` + `tools/l10n-native.json`; руками не править |
| `App/WebAppViewController.swift` | WKWebView, мосты, `selectTab` |
| `Web/index.html` | `__ZIKR_NATIVE_TABS`, `tab.change`, `lang.change`, `suppressTabChange`, `window.zikrNative` (ZKR-50, ZKR-52: `tap / undo / reset / snapshot / explore`, ZKR-53: `markViewed / showChapter`) |

Данные уровней в `index.html` не менялись.

## Как позже заменить одну вкладку на native

Оставить `WebViewManager` и контроллер живыми (JS-состояние, auth). Для выбранной вкладки показывать native-view поверх `WebHostView` (в `ZStack`, гейт `NativeScreenGate`), web view не уничтожать. Tab bar остаётся общим. Флаг-выключатель в `AppContainer` возвращает веб-экран без релиза кода.

Тексты: новые ключи добавляются в `UI` в `index.html` (или в `tools/l10n-native.json`, если строка только нативная), затем `node tools/l10n-from-web.mjs` и новый `case` в `L10nKey`. `node tests/l10n-native.cjs` проверяет, что всё синхронно.

## Тесты

- `ZikrKit` — пакетные тесты (домен, хранилище, гейт).
- `ZikrAdventureTests` — unit-тесты приложения: `SettingsViewModel`, `AccountDeletionFlow`, `LocalizationService`, `ZikrViewModel` (ZKR-52: оптимизм, 200 быстрых нажатий, сверка, сброс, баннер, цель, вибрация/звук), `SerialCommandQueue`, `WebZikrCommandSink`, `SiraViewModel` и `WebSiraCommandSink` (ZKR-53: группы, «Новое», предпросмотр, distText, команды).
- `ZikrAdventureUITests` — «Инфо», «Настройки», «Зикр» и «Путь Сиры». `ZIKR_UITEST_AUTH=signedIn|guest` (только DEBUG) подменяет Firebase.
- `tests/*.cjs` — веб (`node tests/<file>.cjs`).

## Ограничения среды, в которой писался код

ZKR-52 и ZKR-53 собраны и проверены на Mac (Xcode 27.2, симулятор iPhone 17, iOS 27.0): `xcodebuild test`, UI-тесты и скриншоты light/dark сравнены с веб-экраном (`AppContainer.isNativeZikrEnabled = false` / `isNativeSiraEnabled = false`). Ниже — заметка из ZKR-47.

Xcode в этой среде нет. Сборка, симулятор и жесты на устройстве не запускались. Проверены исходники, pbxproj, `project.yml` и `git diff` против `ba79a3f` для `ZikrAdventure-AppStore/`.
