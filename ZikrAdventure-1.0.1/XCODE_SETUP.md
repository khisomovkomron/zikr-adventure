# Настройка Xcode для Firebase Auth (1.1.0)

Проект теперь полностью описан в `project.yml` (XcodeGen). Большинство шагов автоматизированы.

## Вариант А: Автоматическая генерация (рекомендуется)

### 1. Установить XcodeGen (один раз)

```bash
brew install xcodegen
```

### 2. Разместить GoogleService-Info.plist

```bash
cp /path/to/GoogleService-Info.plist ZikrAdventure/GoogleService-Info.plist
```

Файл уже в `.gitignore`, не будет закоммичен.

### 3. Сгенерировать проект

```bash
cd ZikrAdventure-1.0.1
xcodegen generate
```

**Готово!** Проект создан с:
- ✅ Firebase SPM packages (FirebaseCore, FirebaseAuth)
- ✅ GoogleSignIn SPM package
- ✅ Entitlements файл (Sign in with Apple)
- ✅ Все Swift файлы (включая AuthCoordinator)
- ✅ GoogleService-Info.plist в resources (optional, не упадёт если нет)
- ✅ Версия 1.1.0 build 3

### 4. Открыть и собрать

```bash
open ZikrAdventure.xcodeproj
```

Xcode → Product → Build (⌘B) → ожидается **BUILD SUCCEEDED**.

Если SPM packages ещё не загружены, Xcode скачает их автоматически при первой сборке.

---

## Вариант Б: Ручная настройка существующего проекта

Если не хотите использовать XcodeGen, откройте существующий `ZikrAdventure.xcodeproj` и выполните шаги ниже.

### 1. Добавить Swift Package Dependencies

File → Add Package Dependencies...

**Firebase iOS SDK:**
- URL: `https://github.com/firebase/firebase-ios-sdk`
- Version: 11.0.0 или новее (Up to Next Major Version)
- Выбрать продукты:
  - ✅ FirebaseAuth
  - ✅ FirebaseCore

**GoogleSignIn-iOS:**
- URL: `https://github.com/google/GoogleSignIn-iOS`
- Version: 8.0.0 или новее
- Выбрать продукт:
  - ✅ GoogleSignIn

### 2. Добавить GoogleService-Info.plist

Project Navigator → правой кнопкой на папку `ZikrAdventure` → Add Files to "ZikrAdventure"...
- Выбрать `ZikrAdventure/GoogleService-Info.plist`
- ✅ Add to targets → ZikrAdventure

Проверка: Build Phases → Copy Bundle Resources должен включать GoogleService-Info.plist.

### 3. Добавить ZikrAdventure.entitlements

Project settings → ZikrAdventure target → Signing & Capabilities:
- Поле **Code Signing Entitlements** = `ZikrAdventure/ZikrAdventure.entitlements`
- Если поле пустое, вручную ввести путь

### 4. Проверить Swift files

Убедиться что в Build Phases → Compile Sources есть:
- ZikrAdventureApp.swift
- WebAppViewController.swift
- AuthCoordinator.swift
- ProgressFileStore.swift
- BundleSchemeHandler.swift

Если AuthCoordinator.swift отсутствует, добавить вручную.

---

## Общие шаги (для обоих вариантов)

### 5. Apple Developer Portal: включить Sign in with Apple

1. Открыть https://developer.apple.com/account/resources/identifiers/list
2. Найти App ID `com.komronkhisomov.zikradventure`
3. Edit → Capabilities → **Sign in with Apple** ✅
4. Save

После изменения capability:
- Xcode → Preferences → Accounts → Download Manual Profiles
- Или Xcode создаст новый автоматически

**Без этого шага:** Sign in with Apple не будет работать.

### 6. Проверка сборки

```bash
xcodebuild -project ZikrAdventure.xcodeproj \
           -scheme ZikrAdventure \
           -configuration Debug \
           -destination 'platform=iOS Simulator,name=iPhone 15' \
           build
```

Ожидаемый результат: `** BUILD SUCCEEDED **`

### 7. Запуск на устройстве (обязательная проверка)

1. Подключить iPhone
2. Xcode → Product → Destination → ваш iPhone
3. Xcode → Product → Run (⌘R)

**Проверить:**
- Приложение запускается без crash
- Счётчик работает (не регрессировал)
- Настройки → Аккаунт виден (даже если UI пустой, секция должна быть)
- GoogleService-Info.plist загружен (Firebase инициализируется)

---

## Возможные ошибки

**No such module 'FirebaseCore' / 'GoogleSignIn'**
→ Вернуться к шагу 1 (Вариант Б) или пересоздать проект через XcodeGen (Вариант А).

**GoogleService-Info.plist not found in bundle**
→ Убедиться что файл размещён в `ZikrAdventure/GoogleService-Info.plist` и добавлен в Copy Bundle Resources (Вариант Б) или что `xcodegen generate` видит его (Вариант А).

**Missing "Sign in with Apple" entitlement**
→ Проверить шаг 5: capability должна быть включена в Apple Developer Portal.

**Code signing failure**
→ Проверить Development Team в project settings.

---

## Проверка Firebase конфигурации

```bash
python3 tools/check_firebase_config.py ZikrAdventure/GoogleService-Info.plist
```

Ожидается: `PASS: local config is structurally consistent with this iOS app.`

---

## Следующие шаги

После успешной сборки:
1. ✅ ZKR-19 завершена (Account screen UI реализован)
2. → ZKR-21: тестирование реального входа Google и Apple на устройстве
3. → ZKR-22: privacy policy и выпуск

См. `IMPLEMENTATION_REPORT.md` для полного статуса.
