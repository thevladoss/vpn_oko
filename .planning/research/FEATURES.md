# Feature Research

**Domain:** VPN-прототип на Flutter с нативной интеграцией (тестовое задание, 48 часов)
**Researched:** 2026-07-13
**Confidence:** HIGH (скоуп table stakes задан ТЗ), MEDIUM (дифференциаторы — анализ экосистемы v2rayNG/Hiddify и практик сильных тестовых решений)

## Специфика домена

Это не продуктовый VPN, а демонстрация инженерных навыков для ревьюера. «Пользователь» здесь — проверяющий, который за 10–15 минут смотрит видео, README и код. Table stakes определяет ТЗ дословно; дифференциаторы — то, что ревьюер отметит как «сильное решение»; анти-фичи — то, что сожрёт 48 часов без прибавки к оценке.

## Feature Landscape

### Table Stakes (жёстко по ТЗ — отсутствие = провал критерия)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Экран с 5 статусами (Disconnected/Connecting/Connected/Disconnecting/Error) | Явное требование ТЗ, первый пункт видео-демо | LOW | State machine в Dart: sealed class `VpnState`; статус — единственный источник правды для UI |
| Connect/Disconnect с блокировкой в переходных состояниях | Явное требование ТЗ; двойной тап на Connect — классический баг | LOW | Кнопка disabled при Connecting/Disconnecting; выводится из `VpnState`, без отдельных флагов |
| Живой блок логов из native | Явное требование ТЗ и пункт видео | LOW | ListView + событие `logMessage`; лимит буфера (например, 500 строк), чтобы не течь память |
| Отображение сервера и времени подключения | Явное требование ТЗ | LOW | Native отдаёт `connectedAt` timestamp, Dart тикает `Timer.periodic` — таймер переживает пересоздание виджета |
| Статистика трафика (событие `trafficChanged`) | Явное требование ТЗ | MEDIUM | Реальные байты из read-loop TUN-дескриптора (см. дифференциаторы); минимум — периодическое событие с накопленными rx/tx |
| Pigeon-мост: `startVpn(config)`, `stopVpn()`, `getStatus()` | Явное требование ТЗ (метод + контракт) | MEDIUM | Один `.dart`-файл контракта, кодоген Kotlin/Swift; `getStatus()` нужен для восстановления UI после перезапуска Flutter-стороны |
| События native→Flutter: `statusChanged`, `logMessage`, `trafficChanged`, `error` | Явное требование ТЗ | MEDIUM | Pigeon `@EventChannelApi` или `FlutterApi`; события идут с main thread на Android |
| Android `VpnService` + `Builder` (addAddress, addRoute, addDnsServer, establish) | Главный критерий «сильного решения» из ТЗ | MEDIUM | `VpnService.prepare()` обязателен до старта (см. ниже); establish возвращает `ParcelFileDescriptor` |
| Запрос VPN-разрешения (`VpnService.prepare`) + обработка отказа | Неявное требование: без него Connect молча падает на первом же демо | LOW | В ТЗ не назван, но это пререквизит establish; отказ пользователя → статус Error с внятным логом |
| Android Foreground Service + уведомление + lifecycle | Явное требование ТЗ; с Android 14 без него сервис убьют | MEDIUM | Требуется `foregroundServiceType` (для VPN — `specialUse` или `systemExempted`), `POST_NOTIFICATIONS` runtime-разрешение на Android 13+ |
| Корректная остановка + `onRevoke` | Явное требование ТЗ; система отзывает VPN при запуске другого VPN-клиента | MEDIUM | onRevoke → закрыть TUN fd, остановить foreground, событие `statusChanged(Disconnected)` во Flutter |
| iOS: компилируемый skeleton `PacketTunnelProvider` | Явное требование ТЗ (допустима заготовка) | MEDIUM | `startTunnel`/`stopTunnel` с `NEPacketTunnelNetworkSettings`; собирается, но без entitlement не запускается — это ожидаемо |
| iOS: доки про capabilities, entitlements, App Groups, app↔extension | Явное требование ТЗ | LOW | Раздел README; включить схему коммуникации через `NETunnelProviderManager` |
| Парсинг `vless://` в `VlessConfig` + тесты | «Плюсом» в ТЗ, в PROJECT.md — Active requirement | LOW | Формат `vless://uuid@host:port?type=…&security=…&sni=…#name`; `Uri.parse` покрывает 90%, тесты на кривые ссылки обязательны |
| Модели `VpnConfig`/`VpnState`, ошибки на всех слоях | Явное требование ТЗ | LOW | Ошибки native → событие `error` → доменная модель → UI-состояние Error |
| README: запуск, архитектура, план интеграции VPN-core | Явное требование ТЗ и формат сдачи | LOW | План core: sing-box/xray как .aar (Android) / .xcframework (iOS), точки подключения в коде |
| Видео-демо 1–3 минуты | Формат сдачи | LOW | Запуск → Connect → статусы/логи/трафик → Disconnect; снять в конце, когда UI готов |

### Differentiators (сильное решение — то, что выделит кандидата)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Реальный read-loop TUN: подсчёт байтов из `ParcelFileDescriptor` | Трафик-статистика из настоящих пакетов, а не мок — показывает понимание того, как работает TUN | MEDIUM | Поток читает пакеты из fd, суммирует байты, шлёт `trafficChanged` раз в секунду; пакеты можно дропать — форвардинг не нужен |
| Анимированный статус-индикатор | Первое, что видно на видео; пульсация на Connecting, цветовая кодировка 5 состояний | MEDIUM | `AnimatedContainer`/`TweenAnimationBuilder`, без сторонних пакетов; ТЗ говорит «дизайн не важен» — потому это чистый плюс |
| Вставка `vless://` из буфера обмена | Превращает парсер из тестового артефакта в живую фичу; удобно на демо | LOW | `Clipboard.getData` + валидация парсером + отображение распарсенного конфига (host, port, security, sni) |
| Копирование логов в буфер | Ревьюер видит заботу о debug-опыте; одна кнопка | LOW | Кнопка copy-all + опционально long-press на строку |
| Уровни логов с цветами + автоскролл | Блок логов выглядит как инструмент, а не как заглушка | LOW | `info/warning/error` в событии `logMessage`; автоскролл с отключением при ручной прокрутке |
| Ping/задержка сервера (TCP connect time) | Стандарт экосистемы (v2rayNG «tcping»); строка «Server: X · 45 ms» смотрится профессионально | LOW | `Socket.connect(host, port)` + `Stopwatch` в Dart, таймаут 3–5 с; не требует native-кода |
| Скорость трафика (B/s) поверх счётчиков | Из накопленных rx/tx считается дельта в секунду — «живая» цифра на экране | LOW | Считается в Dart из `trafficChanged`; зависит от реального read-loop |
| Unit-тесты state machine / bloc помимо парсера | Тесты сверх требуемых — сигнал зрелости для тестового задания | LOW | Переходы состояний, реакция на `error` и `onRevoke`-сценарий |
| CI: GitHub Actions (analyze + test) | Зелёный бейдж в README — мгновенный сигнал качества | LOW | flutter analyze + flutter test; без сборки APK (долго и хрупко) |
| Mermaid-диаграмма архитектуры в README | Ревьюер понимает мост Flutter→Pigeon→VpnService за 30 секунд | LOW | Одна sequence- или component-диаграмма; GitHub рендерит нативно |
| Восстановление состояния UI при перезапуске приложения | `getStatus()` при старте — VPN живёт в сервисе, UI переподхватывает Connected | LOW | Использует уже обязательный `getStatus()`; частый провал слабых решений |

### Anti-Features (сознательно НЕ делать за 48 часов)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Полная интеграция Xray/sing-box/libv2ray core | «Настоящий VPN» выглядит эффектнее | ТЗ явно говорит «не обязательно»; сборка gomobile .aar, конфиг-маппинг и отладка съедят 20+ часов без гарантии | README-раздел «План интеграции core» с точками подключения в коде (интерфейс `VpnCore`) |
| Форвардинг/парсинг пакетов из TUN (mini-tun2socks, NAT, IP-парсинг) | Кажется логичным шагом после read-loop | Это ядро tun2socks — недели работы; трафик всё равно не критерий ТЗ | Read-loop только считает байты и дропает пакеты; в README честно описать ограничение |
| Рабочий iOS-туннель | «Обе платформы работают» звучит сильнее | Network Extension entitlement выдаёт Apple по заявке; за 48 часов недостижимо | Компилируемый skeleton + подробные доки — ровно то, что ТЗ называет допустимым |
| Список серверов / подписки / импорт конфигов | Все продуктовые VPN так делают | Scope creep: хранение, выбор, UI-списки — ноль очков по критериям ТЗ | Один сервер из vless-ссылки (поле ввода + вставка из буфера) |
| Kill switch, split tunneling, per-app VPN | Стандарт продуктовых VPN | Каждая — отдельный пласт edge cases; ТЗ их не упоминает | Одно предложение в README: `addDisallowedApplication` / `includeAllNetworks` как направления развития |
| Автопереподключение / always-on VPN | «Надёжность» | Гонки состояний, взаимодействие с системным always-on — источник багов на демо | Чистая обработка `onRevoke` и ошибок; reconnect — кнопкой пользователя |
| Speed test (download) | Есть в desktop-клиентах v2ray | Даже v2rayNG на Android его не делает; без core бессмысленно | TCP ping как метрика доступности сервера |
| Persist настроек, темы, локализация, onboarding | «Полировка» | Время уходит на инфраструктуру, которую ревьюер не оценивает | Одна тёмная тема из коробки, строки хардкодом на одном языке |
| Аккаунты, авторизация, платежи | Продуктовый рефлекс | Полностью вне критериев ТЗ | Нет |

## Feature Dependencies

```
VpnService.prepare (разрешение)
    └──requires──> ничего; блокирует всё остальное на Android

VpnService establish (TUN)
    └──requires──> VpnService.prepare
    └──requires──> Foreground Service (Android 8+ для старта, 14+ для типа)

trafficChanged (реальные байты)
    └──requires──> TUN read-loop
                       └──requires──> VpnService establish

Скорость B/s ──requires──> trafficChanged
Таймер подключения ──requires──> statusChanged(Connected) + connectedAt
Восстановление UI ──requires──> getStatus()
onRevoke-обработка ──requires──> statusChanged (иначе UI не узнает)

Ping сервера ──requires──> VLESS-парсер (host:port)
Вставка из буфера ──requires──> VLESS-парсер
Блок логов UI ──requires──> Pigeon events (logMessage)

Уведомление Foreground Service ──requires──> POST_NOTIFICATIONS (Android 13+)
```

### Dependency Notes

- **Всё на Android упирается в `prepare()`:** без выданного разрешения establish кидает исключение; сценарий отказа — обязательный тест-кейс для статуса Error.
- **trafficChanged требует read-loop:** мок-таймер с рандомными байтами формально закрывает ТЗ, но реальный подсчёт из TUN стоит ~2 часа и переводит решение в категорию «сильное».
- **Ping и вставка из буфера строятся на парсере:** обе фичи почти бесплатны после того, как `VlessConfig` готов, и обе демонстрируют парсер вживую на видео.
- **onRevoke конфликтует с автопереподключением:** система отозвала VPN → любая попытка молча переподключиться создаёт цикл; потому reconnect только вручную.

## MVP Definition

### Launch With (v1 — закрывает ТЗ полностью)

- [ ] State machine 5 статусов + экран + Connect/Disconnect с блокировкой — ядро демо
- [ ] Pigeon-мост (3 метода, 4 события) — контракт всего проекта, делается первым
- [ ] `VpnService.prepare` → Builder → establish → TUN read-loop с подсчётом байтов — главный критерий ТЗ
- [ ] Foreground Service (тип + уведомление + POST_NOTIFICATIONS) — без него сервис нежизнеспособен на Android 14+
- [ ] `onRevoke` + корректный stop — явный пункт ТЗ
- [ ] Блок логов + сервер + таймер + трафик в UI — явные пункты ТЗ
- [ ] VLESS-парсер + тесты — «плюс» из ТЗ, дешёвый
- [ ] iOS skeleton + доки — явный пункт ТЗ
- [ ] README (запуск, архитектура, план core) + видео — формат сдачи

### Add After Validation (v1.x — если остаётся время, в порядке цена/эффект)

- [ ] Анимированный статус-индикатор — максимальный эффект на видео за 1–2 часа
- [ ] Вставка `vless://` из буфера + карточка распарсенного конфига — оживляет парсер
- [ ] Ping сервера (TCP connect time) — 30–60 минут, чисто в Dart
- [ ] Копирование логов + уровни с цветами — до часа
- [ ] Восстановление UI через `getStatus()` при старте — использует готовый метод
- [ ] CI (analyze + test) + mermaid-диаграмма в README — час на всё

### Future Consideration (v2+ — только как текст в README)

- [ ] Интеграция sing-box/xray core — план описан, реализация вне 48 часов
- [ ] Рабочий iOS-туннель — после получения entitlement от Apple
- [ ] Split tunneling / kill switch / список серверов — продуктовые фичи вне прототипа

## Feature Prioritization Matrix

| Feature | User Value (для ревьюера) | Implementation Cost | Priority |
|---------|---------------------------|---------------------|----------|
| VpnService + establish + read-loop | HIGH | MEDIUM | P1 |
| Pigeon-мост + 4 события | HIGH | MEDIUM | P1 |
| Экран статусов + кнопки + логи + таймер + трафик | HIGH | LOW | P1 |
| Foreground Service + onRevoke | HIGH | MEDIUM | P1 |
| VLESS-парсер + тесты | MEDIUM | LOW | P1 |
| iOS skeleton + доки | HIGH | MEDIUM | P1 |
| README + видео | HIGH | LOW | P1 |
| Анимированный индикатор | MEDIUM | MEDIUM | P2 |
| Вставка из буфера + карточка конфига | MEDIUM | LOW | P2 |
| Ping сервера | MEDIUM | LOW | P2 |
| Копирование/уровни логов | MEDIUM | LOW | P2 |
| Восстановление UI (`getStatus`) | MEDIUM | LOW | P2 |
| CI + mermaid-диаграмма | MEDIUM | LOW | P2 |
| Скорость B/s | LOW | LOW | P3 |
| Unit-тесты state machine | MEDIUM | LOW | P3 |

**Priority key:**
- P1: обязательно к сдаче (ТЗ)
- P2: добавлять по мере остатка времени, в этом порядке
- P3: только если всё P2 готово

## Competitor Feature Analysis

Ориентиры — зрелые open-source клиенты, чей UI ревьюер скорее всего знает.

| Feature | v2rayNG | Hiddify | Наш прототип |
|---------|---------|---------|--------------|
| Статус подключения | Текст + кнопка | Большая анимированная кнопка-статус | Анимированный индикатор 5 состояний |
| Трафик | Скорость up/down в уведомлении и UI | Использование + total traffic | Счётчики rx/tx из TUN + опционально B/s |
| Задержка сервера | tcping + «real delay» по HTTP через core | Auto lowest ping | TCP connect time (без core «real delay» невозможен) |
| Время подключения | Есть | Есть | Таймер от `connectedAt` |
| Логи | Отдельный экран логов core | Логи core | Живой блок логов моста и сервиса, копирование |
| Импорт конфига | vless/vmess из буфера и QR | Подписки | `vless://` из буфера (QR — вне скоупа) |

Вывод: наш прототип воспроизводит узнаваемый UI-паттерн категории (статус-карточка, трафик, ping, таймер), при этом честно документирует, что без core трафик не проксируется.

## Sources

- ТЗ проекта и `/Users/thevladoss/devs/mobile/vpn_oko/.planning/PROJECT.md` — скоуп table stakes (HIGH)
- [Android Developers: VPN (VpnService, Builder, onRevoke)](https://developer.android.com/develop/connectivity/vpn) — обязательные механики Android (HIGH)
- [Android Developers: Foreground service types required (Android 14)](https://developer.android.com/about/versions/14/changes/fgs-types-required), [Foreground service types](https://developer.android.com/develop/background-work/services/fgs/service-types) — требование типа сервиса (HIGH)
- [Building a Minimal Custom VPN in Android: From TUN Interfaces to Real-Time Status](https://medium.com/@bvenom87/building-a-minimal-custom-vpn-in-android-from-tun-interfaces-to-real-time-status-4847e6e382a1) — паттерн read-loop + подсчёт байтов без core (MEDIUM)
- [XTLS/Xray VLESS outbound](https://xtls.github.io/en/config/outbounds/vless.html), [sing-box VLESS](https://sing-box.sagernet.org/configuration/outbound/vless/) — поля конфига VLESS (HIGH)
- [v2rayNG issues: tcping / real delay](https://github.com/2dust/v2rayNG/issues/3404), [v2rayN tcping discussions](https://github.com/2dust/v2rayN/issues/9278) — практика измерения задержки в экосистеме (MEDIUM)
- [Hiddify: обзор клиентов и фич](https://hiddify.com/manager/client-software-on-android/Tutorial-for-V2rayNG-app/), [HiddifyNG](https://github.com/hiddify/HiddifyNG) — UI-паттерны категории (MEDIUM)
- [flutter/packages: pigeon](https://github.com/flutter/packages/tree/main/packages/pigeon) — возможности моста (HIGH)

---
*Feature research for: Flutter Native VPN Prototype (тестовое задание)*
*Researched: 2026-07-13*
