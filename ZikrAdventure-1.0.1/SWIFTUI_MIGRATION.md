# SwiftUI Foundation — архитектура (ZKR-47)

Каркас нативного SwiftUI-приложения вокруг существующего WKWebView. Пока все пять экранов остаются веб-экранами; следующие задачи эпика (ZKR-50, 48, 52, 53, 57) могут заменять их по одному.

Рабочий проект: `ZikrAdventure-1.0.1/` (1.1.1, build 3). `ZikrAdventure-AppStore/` не меняется.

## Слои

```
ZikrAdventureApp
  └─ TabsView
       ├─ WebHostView  →  WebViewManager.shared.viewController  (один WKWebView)
       └─ NativeTabBar (кастомная нижняя панель, не SwiftUI TabView)
```

`TabView` здесь не используется: системный фон вкладки непрозрачный и перехватывает нажатия. Web view и tab bar — соседние дети `VStack`, не overlay. Один `UIView` не переносится между иерархиями.

## Единственный контроллер

`WebViewManager` создаёт `WebAppViewController` в `init`. Fallback `WebAppViewController()` в `makeUIViewController` отсутствует.

Порядок инициализации:

1. Первый доступ к `WebViewManager.shared` создаёт менеджер и контроллер, сразу выставляет `controller.webViewManager = self`.
2. `WebHostView.makeUIViewController` забирает тот же контроллер, выставляет `appLanguage`, регистрирует `tab.change` handler, кладёт стартовый tab в очередь.
3. SwiftUI добавляет контроллер в иерархию → `viewDidLoad` → загрузка `index.html`.
4. `didFinish` → `webViewDidLoad()` сбрасывает очередь `selectTab`.
5. Сообщения `lang.change` / `tab.change` приходят уже на тот же контроллер, у которого есть `appLanguage` и `webViewManager`.

Один `AuthCoordinator`, один набор `auth.*` handlers, одно JS-состояние.

## Связь native ↔ web

- Native → web: `selectTab(id)` в JS (после загрузки; до загрузки — `pendingSelectTab`).
- Web → native вкладка: `postMessage({ type: "tab.change", tab: id })`.
- Web → native язык: `postMessage({ type: "lang.change", lang, tabs })`; `AppLanguage` хранит названия вкладок в `UserDefaults`.
- Смена языка в вебе ставит `suppressTabChange`, чтобы `selectTab` при перерисовке не дёргал native-вкладку.
- Веб-`#tabbar` скрывается флагом `window.__ZIKR_NATIVE_TABS` (элемент в `index.html` остаётся).

## Файлы каркаса

| Файл | Роль |
|------|------|
| `App/ZikrAdventureApp.swift` | `@main`, Firebase, `TabsView` |
| `App/TabsView.swift` | VStack: web view + NativeTabBar, iOS 16 `onChange(of:)` |
| `App/TabItem.swift` | zikr, map, path, info, settings + SF Symbols |
| `App/WebViewManager.swift` | singleton, eager controller |
| `App/AppLanguage.swift` | язык и заголовки вкладок |
| `App/WebAppViewController.swift` | WKWebView, мосты, `selectTab` |
| `Web/index.html` | `__ZIKR_NATIVE_TABS`, `tab.change`, `lang.change`, `suppressTabChange` |

Данные уровней в `index.html` не менялись.

## Как позже заменить одну вкладку на native

Оставить `WebViewManager` и контроллер живыми (JS-состояние, auth). Для выбранной вкладки показывать native-view вместо `WebHostView`, web view не уничтожать. Tab bar остаётся общим.

## Ограничения среды, в которой писался код

Xcode в этой среде нет. Сборка, симулятор и жесты на устройстве не запускались. Проверены исходники, pbxproj, `project.yml` и `git diff` против `ba79a3f` для `ZikrAdventure-AppStore/`.
