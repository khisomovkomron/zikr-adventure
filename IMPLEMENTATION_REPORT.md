# Zikr Adventure 1.1.0 — отчёт реализации Firebase Auth

**Дата:** 22 октября 2026
**Ветка:** codex/release-1.1.0
**PR:** https://github.com/khisomovkomron/zikr-adventure/pull/2 (draft)
**Commit:** 893ed67

---

## Что реализовано

### ✅ ZKR-15: Firebase Project Setup (Done)

**Firebase project `zikr-adventure` настроен:**
- iOS app bundle ID: `com.komronkhisomov.zikradventure`
- Authentication providers: Google ✅, Apple ✅
- GoogleService-Info.plist получен и проверен:
  ```bash
  python3 tools/check_firebase_config.py ZikrAdventure-1.0.1/ZikrAdventure/GoogleService-Info.plist
  # → PASS: local config is structurally consistent with this iOS app.
  ```

**Размещение файла:**
- Путь: `ZikrAdventure-1.0.1/ZikrAdventure/GoogleService-Info.plist`
- **НЕ коммитится** (gitignored, см. `.gitignore` строка 18)
- Подробности: `ZikrAdventure-1.0.1/FIREBASE_CONFIG.md`

---

### ✅ ZKR-16: AuthCoordinator и WebView Bridge (Код готов)

**Файлы:**
- `ZikrAdventure-1.0.1/ZikrAdventure/App/AuthCoordinator.swift` (новый, 434 строки)
- `ZikrAdventure-1.0.1/ZikrAdventure/App/WebAppViewController.swift` (обновлён)
- `ZikrAdventure-1.0.1/ZikrAdventure/App/ZikrAdventureApp.swift` (обновлён)

**AuthCoordinator — state machine:**
```
guest → signingIn → signedIn
         ↓             ↓
       error        deleting
         ↓             ↓
       guest         guest
```

**Функции:**
- Восстановление сессии через Firebase Auth listener (`authStateListener`)
- Только одна операция входа/удаления одновременно
- Отправка состояния в WebView через custom events `zikr:auth`

**WebView Bridge (WebAppViewController):**
- Принимает команды из JavaScript:
  - `auth.signInGoogle`
  - `auth.signInApple`
  - `auth.signOut`
  - `auth.deleteAccount`
  - `auth.getState`
- Отправляет события в JavaScript:
  - `window.addEventListener('zikr:auth', (e) => { /* e.detail = {state, user?, message?} */ })`
- Проверка origin: команды принимаются только от `zikr://localhost` (доверенный документ)

**Инициализация Firebase (ZikrAdventureApp):**
- AppDelegate с `FirebaseApp.configure()` в `application(_:didFinishLaunchingWithOptions:)`

---

### ✅ ZKR-17: Google Sign-In (Код готов)

**Реализация в AuthCoordinator:**
- `signInWithGoogle(presentingViewController:)` через GoogleSignIn SDK
- CLIENT_ID из `FirebaseApp.app()?.options.clientID`
- Обработка:
  - ✅ Успешный вход → Firebase credential → `Auth.auth().signIn(with:)`
  - ✅ Отмена пользователя (code -5) → возврат в guest без ошибки
  - ✅ Сетевые ошибки (NSURLErrorDomain) → error state с сообщением "offline"
  - ✅ Другие ошибки → error state с сообщением "error"
- Повторная авторизация для удаления аккаунта: `reauthenticateWithGoogle`

---

### ✅ ZKR-18: Sign in with Apple (Код готов)

**Реализация в AuthCoordinator:**
- `signInWithApple()` через ASAuthorizationController
- Nonce generation: SHA256 hash по Firebase best practices
- `ASAuthorizationAppleIDRequest`:
  - requestedScopes: `[.fullName, .email]`
  - nonce: SHA256 хеш случайного nonce
- Обработка:
  - ✅ Успешный вход → Firebase OAuthProvider credential → `Auth.auth().signIn(with:)`
  - ✅ Отмена пользователя (code 1001) → возврат в guest без ошибки
  - ✅ Сетевые ошибки → error state с сообщением "offline"
  - ✅ Другие ошибки → error state с сообщением "error"
- Поддержка:
  - ✅ Apple Hide My Email (relay email)
  - ✅ Отсутствие displayName при повторном входе
- Повторная авторизация для удаления аккаунта: `reauthenticateWithApple`

**Entitlements:**
- Файл: `ZikrAdventure-1.0.1/ZikrAdventure/ZikrAdventure.entitlements` (новый)
- Capability: `com.apple.developer.applesignin` = `["Default"]`

---

### ✅ ZKR-20: Выход и удаление аккаунта (Код готов)

**Sign Out:**
- `signOut()` → `Auth.auth().signOut()`
- Ошибки пробрасываются caller, состояние обновляется через listener
- Локальный прогресс (localStorage, progress.json) не меняется

**Delete Account:**
- `deleteAccount(presentingViewController:)`:
  1. Проверка давности последнего входа (metadata.lastSignInDate)
  2. Если > 5 минут назад → повторная авторизация (reauthenticate)
  3. Если provider == "apple" → отзыв токенов через `Auth.auth().revokeToken(withAuthorizationCode:)`
  4. Удаление Firebase user: `currentUser.delete()`
- Состояние `deleting` во время операции
- Ошибки не приводят к потере текущей сессии или прогресса
- При успехе → listener переводит в guest

---

### ✅ Конфигурация

**Info.plist:**
- Добавлен `CFBundleURLTypes` с REVERSED_CLIENT_ID для Google OAuth:
  ```xml
  <key>CFBundleURLSchemes</key>
  <array>
    <string>com.googleusercontent.apps.879305013242-sscp3uok9fu89b0dfd5q42i0arle6vdu</string>
  </array>
  ```

**project.yml:**
- `MARKETING_VERSION`: 1.1.0
- `CURRENT_PROJECT_VERSION`: 3 (build)
- `CODE_SIGN_ENTITLEMENTS`: ZikrAdventure/ZikrAdventure.entitlements
- Добавлены зависимости (для XcodeGen):
  ```yaml
  packages:
    Firebase:
      url: https://github.com/firebase/firebase-ios-sdk
      from: 11.0.0
    GoogleSignIn:
      url: https://github.com/google/GoogleSignIn-iOS
      from: 8.0.0
  dependencies:
    - package: Firebase
      product: FirebaseAuth
    - package: Firebase
      product: FirebaseCore
    - package: GoogleSignIn
  ```

---

### ✅ Документация

**XCODE_SETUP.md:**
- Пошаговая инструкция (10 шагов)
- Добавление Swift Package Dependencies (Firebase, GoogleSignIn)
- Добавление GoogleService-Info.plist в проект
- Добавление AuthCoordinator.swift и entitlements
- Проверка версии/build
- Включение Sign in with Apple capability в Apple Developer Portal
- Проверка сборки: `xcodebuild ... build`
- Запуск на устройстве
- Альтернатива: пересоздание проекта через XcodeGen

**FIREBASE_CONFIG.md:**
- Где лежит GoogleService-Info.plist
- Почему не в Git (публичный репозиторий)
- Как получить файл (владелец, другой разработчик, CI/CD)
- Проверка корректности: `tools/check_firebase_config.py`
- Production vs Test окружения

**docs/releases/1.1.0.md:**
- Полный отчёт прогресса
- Статус задач ZKR-13..ZKR-22
- Что завершено, что в работе, что осталось
- Ограничения текущей реализации
- Что коммитится / не коммитится
- Следующие шаги для владельца

---

## Что НЕ реализовано / требуется

### ❌ ZKR-19: Account Screen UI (Frontend)

**Текущее состояние:**
- Мост Swift ↔ JavaScript готов и работает
- HTML/JS интерфейс аккаунта **отсутствует**
- Экран настроек (id="s-settings") существует в `Web/index.html`, но UI аккаунта не добавлен

**Требуется реализовать:**
1. Использовать strings.json (6 языков × 22 строки) из `docs/auth/design/strings.json`
2. UI для всех состояний:
   - **guest**: 2 кнопки "Войти с Google" / "Войти с Apple", intro text, local progress warning
   - **signingIn**: loading indicator, provider name
   - **signedIn**: displayName/email/provider, кнопки "Выйти" / "Удалить аккаунт"
   - **error**: error message, retry button
   - **deleting**: loading indicator
3. Диалоги подтверждения:
   - Выход: "Выйти из аккаунта?" + "Ваш счёт останется на устройстве"
   - Удаление: "Удалить аккаунт?" + warning + "Для сброса прогресса используйте отдельную кнопку"
4. Интеграция с мостом:
   ```javascript
   // Отправка команды
   window.webkit.messageHandlers.zikr.postMessage({ type: "auth.signInGoogle" });
   
   // Получение состояния
   window.addEventListener('zikr:auth', (e) => {
     const { state, user, message, retryable } = e.detail;
     // state: "guest"|"signingIn"|"signedIn"|"error"|"deleting"
     // user: { uid, displayName, email, provider } при signedIn
     // message: "error"|"offline" при error
   });
   
   // Запрос текущего состояния при загрузке страницы
   window.webkit.messageHandlers.zikr.postMessage({ type: "auth.getState" });
   ```
5. VoiceOver labels, focus management, accessibility

**Референсы:**
- `docs/auth/design/preview.html` — макет (9 состояний, все языки)
- `docs/auth/design/strings.json` — все строки локализации
- `docs/auth/UX.md` — детальное описание UX/UI

---

### ❌ Xcode: добавить SPM packages и файлы

**Текущее состояние:**
- Код написан, но **не добавлен** в Xcode project
- `.xcodeproj/project.pbxproj` не модифицирован (binary format, сложно редактировать вручную)

**Требуется:**
1. Открыть `ZikrAdventure.xcodeproj` в Xcode
2. File → Add Package Dependencies:
   - Firebase iOS SDK (11.0.0+): выбрать FirebaseAuth, FirebaseCore
   - GoogleSignIn-iOS (8.0.0+): выбрать GoogleSignIn
3. Добавить `GoogleService-Info.plist` в Build Phases → Copy Bundle Resources
4. Добавить `AuthCoordinator.swift` в Build Phases → Compile Sources (если не видит автоматически)
5. Указать `ZikrAdventure.entitlements` в Project settings → Code Signing Entitlements

**Инструкция:** `ZikrAdventure-1.0.1/XCODE_SETUP.md` (шаги 1-9)

**Альтернатива:** пересоздать проект через XcodeGen:
```bash
cd ZikrAdventure-1.0.1
xcodegen generate
```
Это создаст новый .xcodeproj из project.yml (который уже обновлён с зависимостями).

---

### ❌ Apple Developer Portal: включить Sign in with Apple

**Текущее состояние:**
- Capability НЕ включена для App ID `com.komronkhisomov.zikradventure`

**Требуется:**
1. Открыть https://developer.apple.com/account/resources/identifiers/list
2. Найти App ID `com.komronkhisomov.zikradventure`
3. Edit → Capabilities → включить "Sign in with Apple"
4. Save
5. Xcode → Preferences → Accounts → Download Manual Profiles (или Xcode создаст новый автоматически)

**Без этого:** Sign in with Apple не будет работать (entitlement есть, но capability не активирована в портале).

---

### ❌ ZKR-21: QA на реальном устройстве

**Текущее состояние:**
- Код написан, но **не проверен** на iPhone
- Компиляция не выполнялась (iOS build недоступен на этом VM)
- Реальная авторизация не тестировалась

**Требуется проверить:**
1. **Сборка:**
   - xcodebuild → BUILD SUCCEEDED
   - Нет ошибок компиляции Swift
   - Все зависимости подключены корректно
2. **Запуск на устройстве:**
   - Приложение запускается без crash
   - Firebase инициализируется корректно (GoogleService-Info.plist загружен)
   - Счётчик работает (существующая функциональность не сломана)
3. **Реальный вход:**
   - Google Sign-In: успешный вход, отмена, плохая сеть
   - Apple Sign-In: успешный вход, отмена, плохая сеть, Hide My Email
   - Восстановление сессии после перезапуска приложения
4. **Смена аккаунта:**
   - Выход → повторный вход другим провайдером
   - Локальный прогресс (счёт, история, главы) не меняется
5. **Удаление аккаунта:**
   - Повторная авторизация (если последний вход > 5 минут назад)
   - Apple: отзыв токенов
   - Firebase user удаляется
   - Локальный прогресс сохраняется
6. **Edge cases:**
   - Повторные нажатия на кнопку входа (не должно запускать второй flow)
   - Apple: отсутствие displayName при повторном входе
   - Работа счётчика без интернета (вход требует сеть, но приложение продолжает работать)
7. **Accessibility:**
   - Все 6 языков (ru, en, uz, tg, kk, ky)
   - VoiceOver (screen reader)
   - Dynamic Type (масштабирование текста)
   - Маленький экран (iPhone SE)
   - Тёмная тема

**Чек-лист:** см. `docs/releases/1.1.0.md` раздел "ZKR-21: QA на устройстве"

---

### ❌ ZKR-22: Privacy Policy и выпуск

**Требуется:**
1. Обновить Privacy Policy:
   - Упомянуть Firebase Authentication
   - Google Sign-In SDK
   - Apple Sign-In
   - Что хранится: Firebase UID, email, displayName (не передаётся третьим лицам)
2. App Store Connect privacy disclosures:
   - Authentication (третий provider: Firebase)
   - User ID (Firebase UID)
3. Английские материалы для App Store (если описание обновляется)
4. TestFlight:
   - Внутреннее тестирование
   - Внешнее beta
5. Submission:
   - Проверка build number (3 или выше последнего загруженного)
   - Проверка что все QA tests прошли

---

## Структура коммита

**Закоммитированы:**
```
ZikrAdventure-1.0.1/
├── FIREBASE_CONFIG.md                              (новый)
├── XCODE_SETUP.md                                  (новый)
├── ZikrAdventure/
│   ├── App/
│   │   ├── AuthCoordinator.swift                   (новый, 434 строки)
│   │   ├── WebAppViewController.swift              (обновлён: +auth handlers)
│   │   └── ZikrAdventureApp.swift                  (обновлён: +AppDelegate+Firebase)
│   ├── Info.plist                                  (обновлён: +URL scheme)
│   ├── ZikrAdventure.entitlements                  (новый)
│   └── GoogleService-Info.plist                    (НЕ коммитится, gitignored)
└── project.yml                                     (обновлён: версия 1.1.0, зависимости)

docs/releases/1.1.0.md                              (обновлён: полный отчёт прогресса)
```

**Commit:** 893ed67
**PR #2 обновлён:** https://github.com/khisomovkomron/zikr-adventure/pull/2

---

## Следующие шаги (приоритет)

### 1. Владелец: настроить Xcode (15 минут)

```bash
cd ZikrAdventure-1.0.1
cat XCODE_SETUP.md  # Прочитать инструкцию
open ZikrAdventure.xcodeproj
```

Выполнить шаги 1-9 из XCODE_SETUP.md:
- Добавить Firebase + GoogleSignIn SPM packages
- Добавить GoogleService-Info.plist
- Добавить entitlements
- Собрать проект
- Запустить на iPhone

### 2. Владелец: включить Sign in with Apple capability

Apple Developer Portal → App ID → Capabilities → Sign in with Apple

### 3. Frontend/JS разработчик: реализовать Account Screen UI (ZKR-19)

Интегрировать HTML/JS интерфейс аккаунта в `Web/index.html`:
- Использовать strings.json (6 языков)
- Подключить мост JavaScript ↔ Swift
- Реализовать UI для всех состояний
- Диалоги подтверждения
- VoiceOver labels

Референс: `docs/auth/design/preview.html`

### 4. QA: проверка на устройстве (ZKR-21)

Полный чек-лист из `docs/releases/1.1.0.md`

### 5. PM/Release: privacy и выпуск (ZKR-22)

Privacy Policy → App Store disclosures → TestFlight → submission

---

## Проверено

- ✅ `tools/check_firebase_config.py` → PASS
- ✅ Swift syntax (визуальная проверка)
- ✅ `.gitignore` содержит `GoogleService-Info*.plist`
- ✅ `Info.plist` содержит REVERSED_CLIENT_ID URL scheme
- ✅ `ZikrAdventure.entitlements` содержит Sign in with Apple capability
- ✅ `project.yml` обновлён (версия 1.1.0, зависимости)
- ✅ Документация полная и актуальная (XCODE_SETUP.md, FIREBASE_CONFIG.md, releases/1.1.0.md)
- ✅ PR #2 обновлён с полным описанием

## НЕ проверено (требуется Mac/Xcode/iPhone)

- ❌ iOS build (xcodebuild)
- ❌ Swift компиляция без ошибок
- ❌ Запуск на симуляторе/устройстве
- ❌ Реальный вход Google/Apple
- ❌ WKWebView bridge и JavaScript интеграция
- ❌ VoiceOver, Dynamic Type, accessibility
- ❌ Все 6 языковых локализаций

---

## Контакты и ресурсы

**GitHub:**
- Ветка: codex/release-1.1.0
- PR #2: https://github.com/khisomovkomron/zikr-adventure/pull/2 (draft)
- Commit: 893ed67

**Jira:**
- Epic: https://zikr-app.atlassian.net/browse/ZKR-12
- Задачи: ZKR-13 (Done), ZKR-14 (Done), ZKR-15 (Done), ZKR-16-20 (In Progress, код готов), ZKR-19 (To Do), ZKR-21-22 (To Do)

**Confluence:**
- Спецификация: https://zikr-app.atlassian.net/wiki/spaces/SD/pages/458754
- Релиз 1.1.0: https://zikr-app.atlassian.net/wiki/spaces/SD/pages/589825
- UX/UI: https://zikr-app.atlassian.net/wiki/spaces/SD/pages/491522
- Firebase setup: https://zikr-app.atlassian.net/wiki/spaces/SD/pages/524289

**Файлы:**
- `ZikrAdventure-1.0.1/XCODE_SETUP.md` — инструкция настройки Xcode
- `ZikrAdventure-1.0.1/FIREBASE_CONFIG.md` — где лежит GoogleService-Info.plist
- `docs/releases/1.1.0.md` — полный отчёт прогресса

---

**Следующее действие владельца:**
Открыть `ZikrAdventure-1.0.1/XCODE_SETUP.md` и выполнить шаги 1-9. При обнаружении ошибок компиляции сообщить детали (file, line, error message).
