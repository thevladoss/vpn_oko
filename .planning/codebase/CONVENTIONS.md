# Conventions

## Код

- Feature-first clean architecture: `lib/features/<feature>/{domain,data,presentation}`, общее — в `lib/core/` и `lib/app/`
- SOLID обязателен: зависимости только через абстракции domain-слоя; presentation не знает про data; конструкторная инъекция, composition root в `lib/app/di.dart`
- Комментарии в коде запрещены (Dart, Kotlin, Swift). Имена и структура несут смысл сами. В `analysis_options.yaml` — `very_good_analysis` с `public_member_api_docs: false`
- State management: Bloc (`flutter_bloc`). Бизнес-логика в `Bloc`/`Cubit`, виджеты — только `BlocBuilder`/`BlocListener` и разметка
- Модели domain: sealed classes + equatable, immutable. Никакого freezed/json_serializable — единственный кодоген в проекте pigeon
- Pigeon: контракт в `pigeons/vpn_api.dart`, типы контракта с суффиксом `Message`; импорт `*.g.dart` разрешён только в `core/bridge/` и `features/*/data/`; мапперы переводят DTO в entity
- События native→Flutter отправляются только с main thread платформы (Kotlin: `Handler(Looper.getMainLooper())` / `Dispatchers.Main`; Swift: `DispatchQueue.main`)
- Ошибки: PlatformException → typed Failure в data-слое; UI получает доменные ошибки, не строки платформы
- Kotlin: state machine соединения внутри сервиса, native — источник истины по статусу VPN
- Именование: Dart — `lowerCamelCase`/`UpperCamelCase`, файлы `snake_case.dart`; Kotlin/Swift — конвенции платформ

## Тесты

- Test-as-you-go: код → тесты → прогон в том же заходе; перед коммитом весь набор зелёный
- mocktail для моков; приоритет: VLESS-парсер, мапперы событий, Bloc-переходы (включая error и onRevoke-сценарий)

## Язык

- Код и идентификаторы — английский
- README, доки, commit messages, общение — русский

## Git

- Атомарные коммиты по задачам плана; conventional commits (`feat:`, `fix:`, `docs:`, `test:`, `chore:`) с русским описанием
