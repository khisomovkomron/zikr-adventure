# Настройка Xcode для Firebase Auth (1.1.0)

Этот документ описывает обязательные действия в Xcode после загрузки кода. Все Swift-файлы и конфигурация написаны; остаются только операции в IDE и Apple Developer.

## 1. Открыть проект

```bash
cd ZikrAdventure-1.0.1
open ZikrAdventure.xcodeproj
```

## 2. Добавить Swift Package Dependencies

В Xcode: File → Add Package Dependencies...

### Firebase iOS SDK
- URL: `https://github.com/firebase/firebase-ios-sdk`
- Version: 11.0.0 или новее (Up to Next Major Version)
- Выбрать продукты для добавления:
  - ✅ **FirebaseAuth**
  - ✅ **FirebaseCore**
  - ❌ FirebaseAnalytics (не используется)
  - ❌ FirebaseFirestore (не используется)

### GoogleSignIn-iOS
- URL: `https://github.com/google/GoogleSignIn-iOS`
- Version: 8.0.0 или новее (Up to Next Major Version)
- Выбрать продукт:
  - ✅ **GoogleSignIn**

Нажать Add Package для обоих.

## 3. Добавить GoogleService-Info.plist в проект

В Xcode Project Navigator:
1. Правой кнопкой на папку `ZikrAdventure` → Add Files to "ZikrAdventure"...
2. Выбрать файл `ZikrAdventure/GoogleService-Info.plist`
3. ✅ Убедиться что выбрано: "Copy items if needed" (должно быть ВЫКЛЮЧЕНО, файл уже на месте)
4. ✅ Убедиться что выбрано: Add to targets → ZikrAdventure
5. Нажать Add

**ВАЖНО:** Файл должен быть в папке с синей иконкой (ресурс приложения), не в папке с жёлтой иконкой (группа без привязки к файловой системе).

Проверка: Build Phases → Copy Bundle Resources должен включать GoogleService-Info.plist.

## 4. Добавить AuthCoordinator.swift в проект

Если Xcode не видит `AuthCoordinator.swift` автоматически:
1. Правой кнопкой на папку `ZikrAdventure/App` → Add Files to "ZikrAdventure"...
2. Выбрать `ZikrAdventure/App/AuthCoordinator.swift`
3. ✅ Add to targets → ZikrAdventure
4. Нажать Add

Проверка: Build Phases → Compile Sources должен включать AuthCoordinator.swift.

## 5. Добавить ZikrAdventure.entitlements

В Project Navigator:
1. Правой кнопкой на папку `ZikrAdventure` → Add Files to "ZikrAdventure"...
2. Выбрать файл `ZikrAdventure/ZikrAdventure.entitlements`
3. ✅ Add to targets → ZikrAdventure
4. Нажать Add

Затем в Project settings → ZikrAdventure target → Signing & Capabilities:
1. Проверить что поле **Code Signing Entitlements** = `ZikrAdventure/ZikrAdventure.entitlements`
2. Если поле пустое, вручную ввести путь или выбрать через file picker

## 6. Проверить версию и build

В Project settings → ZikrAdventure target → General:
- **Version**: 1.1.0 (должно быть уже установлено)
- **Build**: 3 или выше (выше последнего загруженного в App Store Connect)

Если значения не установлены автоматически:
- Identity → Version = `1.1.0`
- Identity → Build = `3`

## 7. Apple Developer Portal: включить Sign in with Apple

1. Открыть https://developer.apple.com/account/resources/identifiers/list
2. Найти App ID `com.komronkhisomov.zikradventure`
3. Edit → Capabilities → найти **Sign in with Apple**
4. ✅ Включить Sign in with Apple
5. Save

После изменения capability потребуется новый Provisioning Profile:
- Xcode → Preferences → Accounts → Download Manual Profiles
- Или: Xcode автоматически создаст новый Automatic profile при следующей сборке

## 8. Проверка сборки

```bash
# Из корня ZikrAdventure-1.0.1
xcodebuild -project ZikrAdventure.xcodeproj \
           -scheme ZikrAdventure \
           -configuration Debug \
           -destination 'platform=iOS Simulator,name=iPhone 15' \
           build
```

Ожидаемый результат: `** BUILD SUCCEEDED **`

### Возможные ошибки

**No such module 'FirebaseCore' / 'GoogleSignIn'**
→ Вернуться к шагу 2, убедиться что пакеты добавлены и выбраны нужные продукты.

**GoogleService-Info.plist not found in bundle**
→ Вернуться к шагу 3, убедиться что файл добавлен в Copy Bundle Resources.

**Missing "Sign in with Apple" entitlement**
→ Убедиться что entitlements файл указан в project settings (шаг 5) и capability включена в Developer Portal (шаг 7).

**Code signing failure**
→ Проверить Development Team в project settings. Для локальной сборки можно временно выбрать "Automatically manage signing".

## 9. Запуск на устройстве (обязательная проверка)

1. Подключить iPhone
2. Xcode → Product → Destination → выбрать ваш iPhone
3. Xcode → Product → Run (⌘R)

**Обязательные проверки на реальном устройстве:**
- Приложение запускается
- Можно выполнить зикр (счётчик работает)
- Настройки → открывается экран (даже если UI аккаунта ещё не реализован в HTML)
- GoogleService-Info.plist загружен (нет crash при старте)

## 10. Проверка Firebase конфигурации (из терминала)

```bash
cd /path/to/workspace
python3 tools/check_firebase_config.py ZikrAdventure-1.0.1/ZikrAdventure/GoogleService-Info.plist
```

Ожидаемый результат: `PASS: local config is structurally consistent with this iOS app.`

Если FAIL, проверить что файл GoogleService-Info.plist скачан из правильного Firebase-проекта для bundle ID `com.komronkhisomov.zikradventure`.

## Следующие шаги

После успешной сборки:
1. Реализовать интеграцию Account screen в HTML/JS (ZKR-19) — использовать мост `window.webkit.messageHandlers.zikr.postMessage({ type: "auth.signInGoogle" })` и слушать события `window.addEventListener('zikr:auth', ...)`.
2. Тестирование реального входа Google и Apple на устройстве (ZKR-21).
3. Проверка выхода, повторной авторизации и удаления аккаунта (ZKR-20).

## Альтернатива: пересоздать проект через XcodeGen

Если проект сломан или хотите чистую генерацию:

```bash
brew install xcodegen
cd ZikrAdventure-1.0.1
xcodegen generate
```

Это создаст новый .xcodeproj из project.yml. Затем выполнить шаги 2-9 выше.

**ВНИМАНИЕ:** XcodeGen перезапишет .xcodeproj. Если есть локальные изменения в Xcode (схемы, breakpoints), они будут потеряны.

## Проблемы и поддержка

- Confluence: https://zikr-app.atlassian.net/wiki/spaces/SD/pages/524289 (FIREBASE_SETUP.md)
- Jira: ZKR-16, ZKR-17, ZKR-18 для iOS-задач
- Файлы: `ZikrAdventure-1.0.1/ZikrAdventure/App/AuthCoordinator.swift`, `WebAppViewController.swift`, `ZikrAdventureApp.swift`
