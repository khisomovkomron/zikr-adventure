# GoogleService-Info.plist: размещение и управление

## Расположение файла

**Рабочая копия (не коммитится):**
```
ZikrAdventure-1.0.1/ZikrAdventure/GoogleService-Info.plist
```

Файл находится в папке проекта, но **не отслеживается Git** (`.gitignore` содержит `GoogleService-Info*.plist`).

## Почему не в Git

Репозиторий **публичный** (https://github.com/khisomovkomron/zikr-adventure).
GoogleService-Info.plist содержит:
- `API_KEY` — Firebase Web API key (не секретный, но лучше не публиковать)
- `CLIENT_ID` / `REVERSED_CLIENT_ID` — OAuth client identifiers
- `PROJECT_ID` — Firebase project ID

Эти данные не позволяют злоумышленнику получить доступ к Firebase Console или изменить настройки, но могут использоваться для:
- Попыток авторизации от имени приложения
- Расхода квоты Firebase проекта
- Фишинговых атак (если злоумышленник выпустит похожее приложение с теми же credentials)

**Решение:** файл `.gitignore` содержит правило `GoogleService-Info*.plist`, поэтому файл остаётся локальным.

## Как получить файл

1. **Владелец проекта:**
   - Firebase Console → Project settings → iOS apps → Download GoogleService-Info.plist
   - Сохранить в `ZikrAdventure-1.0.1/ZikrAdventure/GoogleService-Info.plist`
   - Добавить в Xcode (см. XCODE_SETUP.md шаг 3)

2. **Другой разработчик:**
   - Запросить файл у владельца (через защищённый канал, не публичный чат)
   - Или: получить доступ к Firebase Console и скачать самостоятельно
   - Положить в ту же папку `ZikrAdventure-1.0.1/ZikrAdventure/`

3. **CI/CD (Codemagic, GitHub Actions):**
   - Добавить GoogleService-Info.plist как **environment secret** или **secure file**
   - В build script скопировать файл в `ZikrAdventure-1.0.1/ZikrAdventure/` перед xcodebuild
   - Пример для GitHub Actions:
     ```yaml
     - name: Restore Firebase config
       run: echo "${{ secrets.FIREBASE_CONFIG }}" | base64 -d > ZikrAdventure-1.0.1/ZikrAdventure/GoogleService-Info.plist
     ```

## Проверка корректности файла

```bash
python3 tools/check_firebase_config.py ZikrAdventure-1.0.1/ZikrAdventure/GoogleService-Info.plist
```

**PASS** означает:
- Все обязательные поля присутствуют
- `BUNDLE_ID` совпадает с `com.komronkhisomov.zikradventure`
- `CLIENT_ID` валиден для iOS (`.apps.googleusercontent.com`)
- `REVERSED_CLIENT_ID` корректно сформирован
- `IS_SIGNIN_ENABLED` = true

**НЕ проверяется:**
- Принадлежность Firebase-проекта владельцу
- Включены ли Google/Apple providers в Firebase Authentication
- Работает ли реальный вход (требуется запуск на устройстве)

## Альтернатива: приватный репозиторий

Если репозиторий станет приватным:
1. Можно удалить `GoogleService-Info*.plist` из `.gitignore`
2. Закоммитить файл: `git add -f ZikrAdventure-1.0.1/ZikrAdventure/GoogleService-Info.plist`
3. Обновить README: указать что credentials в Git

**Плюсы:** проще для команды, не нужно передавать файл отдельно.
**Минусы:** если репозиторий случайно станет публичным, credentials утекут; сложнее управлять разными окружениями (test/production).

## Production vs Test окружения

Текущий файл использует Firebase project **zikr-adventure** (production).

Для тестов рекомендуется отдельный Firebase-проект:
1. Создать новый проект `zikr-adventure-test` в Firebase Console
2. Добавить iOS app с bundle ID `com.komronkhisomov.zikradventure.test` (или оставить тот же ID, если хотите переключать конфигурации без пересборки)
3. Скачать `GoogleService-Info.plist` для тестового проекта
4. Переключение окружений:
   - Вручную: заменить файл перед сборкой
   - Через Xcode: использовать Build Configurations (Debug = test, Release = production)
   - Через script: `cp configs/GoogleService-Info-test.plist ZikrAdventure/GoogleService-Info.plist`

## См. также

- `docs/auth/FIREBASE_SETUP.md` — инструкция создания Firebase-проекта
- `tools/check_firebase_config.py` — скрипт проверки
- `XCODE_SETUP.md` — добавление файла в Xcode
- `.gitignore` строка 18: `GoogleService-Info*.plist`
