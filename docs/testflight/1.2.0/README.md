# TestFlight 1.2.0 — подготовка и приёмка

Задача: ZKR-68. Основная ветка приёмки: `release/1.2.0`. `main` не менять до подтверждения Комрона после TestFlight. TestFlight не означает публикацию App Store.

## Текущее состояние

- PR #17 слит в release/1.2.0, aa81f08; нативные экраны/онбординг/writer и миграция включены.
- В ветке подготовки версия согласованно установлена в 1.2.0 (project.yml/pbxproj).
- Release iphoneos build без подписи PASS. Это не подписанный archive/IPA и не проверка устройства.
- После принятия соглашений API доступен: последний загруженный build 4, выбран build 5. Версия 1.2.0 (5) согласована в project.yml/pbxproj.
- Прежний блокер соглашений устранён владельцем. API подтвердил существующее приложение 6820335339 и bundle ID; Team 742Y7LBK4U совпала с зарегистрированным prefix и сохранённой Team Xcode.
- Используется существующая Team и automatic signing. Для provisioning поддержан существующий ASC API-ключ через ASC_KEY_PATH; приватные ключи/credentials в Git не сохраняются. Не создавать новый app/bundle ID и не отзывать чужие сертификаты.
- Для 1.2.0 (5) архив/Distribution IPA созданы, codesign/profile/исходные entitlements/Firebase config сверены; Apple validation PASS. Фактический статус upload/processing и доступность тестерам записываются в Confluence/Jira ZKR-68 по ответу Apple. Успешная валидация ещё не означает доступность TestFlight.

## После принятия соглашений

1. Issuer ID сохранён локально в игнорируемом `.env.appstoreconnect` (режим 600); Python preflight читает его без выполнения shell-кода. При необходимости задать `ASC_ISSUER_ID` и `ASC_KEY_PATH` (путь к существующему AuthKey_KEYID.p8) локально. Для shell-архива `ASC_ISSUER_ID` должен быть экспортирован в окружение. Не добавлять значения/ключ в Git. Для утилиты нужны установленные PyJWT и cryptography.
2. `python3 tools/testflight_preflight.py` — read-only проверка существующего приложения и всех загруженных build.
3. На отдельной codex-ветке выполнить `python3 tools/testflight_preflight.py --apply-build`. Она выбирает целочисленный build выше всех загруженных и текущего, меняет project.yml/pbxproj. При отказе API файлы не меняются. Нецелочисленные старые build требуют ручного выбора.
4. Проверить diff и commit; PR из task-ветки обратно в release/1.2.0. После проверки/принятия включить его в release/1.2.0 и архивировать именно её. Main не менять. Не менять bundle identifier, Team приложения, storage keys или App Store app record.
5. Указать `ZIKR_TEAM_ID` существующего приложения и абсолютный `ZIKR_EXPORT_DIR` вне репозитория. При API provisioning задать `ASC_KEY_PATH`. Запустить `tools/archive_testflight.sh`: archive/export для iPhone, jobs=2, без симулятора и без регистрации устройства. Утилита повторно читает ASC и не архивирует build ≤ последнего загруженного. Archive создаётся без Development-профиля, затем локальная промежуточная ad-hoc подпись сохраняет исходные entitlements. Export заменяет её настоящей App Store distribution-подписью (automatic/cloud signing). Финальный IPA никогда не должен оставаться ad-hoc/development. Доступ/профили должны быть действующими. Скрипт verify_testflight_ipa.py проверяет metadata, codesign, исходные entitlements, distribution profile, Firebase config и пишет hash/source commit; любое расхождение останавливает подготовку. Этот шаг **не загружает и не раздаёт** сборку.
6. Проверить в архиве версию/build, подпись/entitlements/Team, встроенный Firebase config, bundle ID; выполнить Validate App в Xcode Organizer.
7. Загрузить в существующее приложение ASC через Organizer/Transporter. Дождаться processing, записать фактический build/дату/commit, ответить на export compliance по реальному составу приложения. Использовать WHAT_TO_TEST.en.md. Не приглашать новых внешних тестировщиков без поручения.
8. Передать Комрону существующий внутренний TestFlight build; закрывать задачу загрузки только после подтверждения processing/доступности.

## Чек-лист приёмки Комроном

Для каждого результата — build, модель iPhone, iOS, язык, тема, шаги, ожидаемое/фактическое, снимок.

- [ ] Обновление **поверх** App Store без удаления: total/daily/history, settings/lang, unlocked/viewed, onboarded и камера/город сохранены; повторный запуск сохраняет состояние. Отдельно проверить старую HTML-установку и пустую новую установку на другом тестовом устройстве.
- [ ] Нажатия (включая быстрые), три счётчика/цель синхронны; undo, оба reset, история, перезапуск, background/foreground и смена дня. Оба reset счётчика сохраняют дневную историю; вариант «счётчик и главы» дополнительно очищает unlocked/viewed. Полный сброс прогресса в Настройках очищает историю, но сохраняет настройки и завершённый онбординг.
- [ ] Онбординг: язык/три шага/Skip/завершение; завершённый пользователь не видит его повторно.
- [ ] Карта: pan/pinch, камеры, города/точки, locked/unlocked/preview, карточки, переходы из Сиры/баннера.
- [ ] Сира: пороги открытия, чтение, снятие «Новое», viewed после перезапуска.
- [ ] Google/Apple: вход/отмена/сеть/перезапуск/выход; повторная авторизация перед удалением на всех языках; Apple revoke; отмена/ошибка не удаляет пользователя. Локальный прогресс сохраняется при выходе/удалении аккаунта.
- [ ] 6 языков, обе темы, малый/большой iPhone, Dynamic Type, VoiceOver, Reduce Motion (ZKR-43).
- [ ] Размер/запуск и App Privacy сверены перед App Store; отсутствие новых сборов данных не утверждается без проверки.

## Баги и выход из beta

1. Проверить дубликат в Jira; создать bug (в проекте Task + label bug), fixVersion 1.2.0, указать build/шаги/влияние.
2. Ветка `codex/zkr-KEY-short-name` от актуальной `release/1.2.0` → исправление/целевые проверки → PR **в release/1.2.0**.
3. После проверок и принятия PR — новый, сверенный с ASC build и повторный TestFlight. Приёмку старого build не переносить автоматически на изменённый код.
4. Старый веб-код удалять на этапе ZKR-59 после приёмки; минимальный legacy-reader сохранить для совместимых обновлений. После очистки ещё один build/smoke.
5. После закрытия блокирующих багов и подтверждения Комрона — PR release/1.2.0 → main, тег проверенного исходника и отдельно App Store. Jira version не released до подтверждённой публикации.

## Проверки подготовки

124 SwiftPM, 9 Node-наборов и 4 генератора PASS после merge без симулятора (21.11). iOS app unit 112 / функциональный UI 16 + повтор 3 счётчика — предыдущие прогоны 19.11. Новый симулятор/device QA не запускался. У Release-сборки есть прежние actor-isolation warnings (Swift 5, будущий Swift 6) и AppIntents metadata warning; не заявляем «без предупреждений».

## ZKR-69 — защита signing pipeline

До загрузки обнаружено: unsigned archive при обычном cloud export терял Apple Sign In entitlement. Первый такой IPA отклонён локальной проверкой и не загружен. Проверенный путь: промежуточная ad-hoc подпись архива с исходными entitlements → automatic distribution export → строгая проверка итогового IPA. Встроенные сертификаты/профили не отзываются; локальный Distribution private key не требуется при cloud signing.

Положительный тест: исправленный IPA содержит исходные entitlements, profile и get-task-allow=false, codesign deep/strict PASS, Apple validation PASS. Отрицательный тест: исходный IPA без Sign in with Apple отвергается новым guard. Это не подтверждает реальную авторизацию на устройстве — её проверяет Комрон в TestFlight.
