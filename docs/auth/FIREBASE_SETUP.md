# Настройка Firebase для авторизации 1.1.0

Это инструкция владельцу; проекты и credentials ещё не созданы. Она не означает работающую авторизацию.

1. Открыть https://console.firebase.google.com/ и создать проект, например Zikr Adventure Test. Можно использовать другой уникальный project ID, выбранный консолью.
2. На шаге Google Analytics выключить Analytics: в 1.1.0 он не нужен. Не создавать Firestore — облачная синхронизация не входит в релиз.
3. В Project overview добавить iOS-приложение. Bundle ID: com.komronkhisomov.zikradventure (точно как в Xcode). Nickname: Zikr Adventure iOS Test.
4. Скачать GoogleService-Info.plist. Сохранить вне отслеживаемых исходников, например /private/tmp/zikr-firebase/GoogleService-Info.plist, и сообщить путь. Не скачивать service-account private key для клиентского приложения.
5. Authentication → Get started → Sign-in method: включить Google, выбрать support email и сохранить. Если Google config изменился, скачать актуальный GoogleService-Info.plist заново.
6. В Apple Developer проверить App ID для того же bundle identifier и включить Sign in with Apple. После изменения потребуется актуальный provisioning profile. Настройку capabilities и Google URL scheme в проекте выполняет разработчик.
7. Authentication → Sign-in method: включить Apple. Требуемые поля зависят от выбранного native/web OAuth flow; заполнить по официальному руководству Firebase Apple. Если требуются Services ID, Team ID, Key ID и .p8, создавать их в аккаунте владельца; .p8 не отправлять в чат и не помещать в Git. Private key используется только в предусмотренной серверной/консольной настройке, не в HTML или приложении.
8. Для production подготовить отдельный проект и документировать переключение окружения. Нельзя выпускать тестовую конфигурацию как production без проверки.

Что сообщить разработчику: Firebase project ID, путь к GoogleService-Info.plist, включён ли Google, включён ли Apple и завершена ли настройка Apple App ID. Пароли, provider secrets, service-account JSON и .p8 не нужны в чат.

Источники:
- https://firebase.google.com/docs/ios/setup
- https://firebase.google.com/docs/auth/ios/google-signin
- https://firebase.google.com/docs/auth/ios/apple

Confluence: https://zikr-app.atlassian.net/wiki/spaces/SD/pages/524289

## Проверка готовности ZKR-15

Подготовлен tools/check_firebase_config.py. Запуск:

```bash
python3 tools/check_firebase_config.py /private/tmp/zikr-firebase/GoogleService-Info.plist
```

Проверяются структура plist, обязательные поля, существующий bundle identifier и соответствие Google CLIENT_ID/REVERSED_CLIENT_ID. Ключи и значения credentials не печатаются. PASS означает только структурную согласованность; включение провайдеров, владение проектом, Apple capability, подпись и реальный вход проверяются отдельно. Флаг Analytics в plist сам по себе не доказывает сбор аналитики; Analytics SDK в релиз не включается.

На текущей проверке файл не найден в рабочей папке, /private/tmp/zikr-firebase и Downloads. Требуется действие владельца: создать Firebase-проект по шагам выше и сообщить путь к файлу. Вход не реализован и не проверен. ZKR-15 не завершена.
