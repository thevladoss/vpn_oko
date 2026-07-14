---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: executing
stopped_at: Completed 05-01-PLAN.md
last_updated: "2026-07-14T02:50:26.701Z"
last_activity: 2026-07-14 -- Phase 05 execution started
progress:
  total_phases: 6
  completed_phases: 4
  total_plans: 31
  completed_plans: 30
  percent: 67
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-07-13)

**Core value:** Реально работающий Android VpnService с живым потоком статусов и логов из native во Flutter через чистый типобезопасный мост.
**Current focus:** Phase 05 — ios-network-extension

## Current Position

Phase: 05 (ios-network-extension) — EXECUTING
Plan: 3 of 3
Status: Executing Phase 05
Last activity: 2026-07-14 -- Phase 05 execution started

Progress: [██████████] 97%

## Performance Metrics

**Velocity:**

- Total plans completed: 0
- Average duration: —
- Total execution time: 0.0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

**Recent Trend:**

- Last 5 plans: —
- Trend: —

*Updated after each plan completion*
| Phase 01 P01 | 5min | 2 tasks | 7 files |
| Phase 01 P02 | 5min | 2 tasks | 14 files |
| Phase 01 P05 | 43min | 2 tasks | 4 files |
| Phase 01 P06 | 2min | 2 tasks | 4 files |
| Phase 01 P03 | 5min | 2 tasks | 9 files |
| Phase 01 P04 | 12min | 2 tasks | 10 files |
| Phase 02 P01 | 3min | 2 tasks | 4 files |
| Phase 02 P02 | 2min | 2 tasks | 2 files |
| Phase Phase 02 PP03 | 6min | 2 tasks | 1 files |
| Phase 02 P04 | 2min | 2 tasks | 3 files |
| Phase 02 P05 | 2min | 1 tasks | 2 files |
| Phase 03 P01 | 12min | 2 tasks | 13 files |
| Phase 03 P02 | 6min | 2 tasks | 6 files |
| Phase 03 P04 | 3min | 2 tasks | 7 files |
| Phase 03 P05 | 6min | 2 tasks | 4 files |
| Phase 03 P06 | 4min | 2 tasks | 8 files |
| Phase 03 P07 | 8min | 1 tasks | 3 files |
| Phase 04 P01 | 4min | 2 tasks | 7 files |
| Phase 04-vless P03 | 2min | 2 tasks | 4 files |
| Phase 04 P04 | 2min | 2 tasks | 5 files |
| Phase 04 P05 | 6min | 2 tasks | 4 files |
| Phase 05 P01 | 16min | 2 tasks | 6 files |
| Phase 05 P02 | 14min | 2 tasks | 4 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Init: Маршрут TUN — узкая тестовая подсеть (интернет живёт в Connected; счётчики демонстрируются пингом в подсеть туннеля) — выбор пользователя
- Init: Демо-конфиг VLESS — зашитый пример в коде (реальную ссылку пользователь может дать ближе к демо; в репо она не попадает)
- Init: README на русском; ТЗ-docx в .gitignore, в публичный репозиторий не попадает
- Init: State management через Bloc (flutter_bloc), не Riverpod (прямое указание пользователя; research предлагал Riverpod)
- Init: iOS делается полноценно: Swift Pigeon-мост + реальный NE-таргет, проверка через TestFlight (Apple Developer аккаунт есть)
- Init: Pigeon (@HostApi + @EventChannelApi, sealed-события) вместо сырых MethodChannel/EventChannel
- Init: Feature-first clean architecture, SOLID, без комментариев в коде
- [Phase ?]: 01-01: поле ErrorMessage.description переименовано в message (конфликт с NSObject.description в Swift, pigeon 27.1.1)
- [Phase ?]: 01-01: pigeon 27.x генерирует VpnEventsStreamHandler на Kotlin и Swift — @FlutterApi-fallback снят; точные символы моста в 01-01-SUMMARY
- [Phase ?]: 01-02: доменные модели sealed/immutable через equatable (VpnState + value objects); репозитории — abstract interface class, реализация в data-слое
- [Phase ?]: 01-02: one_member_abstracts отключён в analysis_options под single-method repository-абстракции Clean Architecture (LogRepository)
- [Phase ?]: 01-05: echo LogMessage.level="info" (нижний регистр) — контракт с LogLevel.values.byName маппера 01-03
- [Phase ?]: 01-05: Android echo — доставка sink с main thread через Handler(Looper.getMainLooper()); VpnEventBus (object) кэширует last-status и реплеит новому подписчику
- [Phase 01]: 01-06: iOS echo-мост зарегистрирован в didInitializeImplicitFlutterEngine через applicationRegistrar.messenger() (шаблон Flutter 3.44, не rootViewController); события с DispatchQueue.main, replay lastStatus в onListen, снапшот в getStatus
- [Phase 01]: 01-06: три Bridge/*.swift добавлены в Sources таргета Runner правкой project.pbxproj вручную (objectVersion 54, без синхронизированных групп); flutter build ios --no-codesign собирается
- [Phase 01]: VpnBridge — единственный владелец подписки на vpnEvents(); фичи читают broadcast-стримы (T-1-04) — Одна подписка + exhaustive switch по sealed демультиплексирует один event channel; тест на throwsStateError подтверждает единственного consumer
- [Phase 01]: logToEntity резолвит LogLevel через firstWhere+orElse:info вместо byName (T-1-09) — Уровень с native — свободная строка; case-insensitive match с fallback исключает ArgumentError на неизвестном значении
- [Phase ?]: 01-04: repository двойной replay — native onListen + Dart-кэш _last; watchState() отдаёт _last первым (BRG-04)
- [Phase ?]: 01-04: Failure implements Exception — connect() бросает типизированный VpnStartFailure без inline-ignore only_throw_errors
- [Phase ?]: 01-04: composition root AppDependencies — единственный вызов vpnEvents(); harness ходит через usecase, g.dart изолирован в di.dart (Pitfall 5)
- [Phase ?]: 02-01: canTransition — public top-level рантайм-гейт переходов (не private/тестовый), OkoVpnService.transition() из плана 03 обязан звать её
- [Phase ?]: 02-01: VpnEventBus укреплён потокобезопасностью — CopyOnWriteArraySet + @Volatile lastStatus/snapshot (emit из read-loop/ticker/onRevoke без ConcurrentModificationException, Pitfall 5)
- [Phase ?]: 02-01: minSdk 24→26 (build.gradle.kts) — безветочные NotificationChannel/startForegroundService для FGS; junit:junit:4.13.2 в testImplementation, автогейт :app:testDebugUnitTest
- [Phase 02]: 02-02: манифест декларирует OkoVpnService с BIND_VPN_SERVICE + exported=false + intent-filter android.net.VpnService (T-2-02); foregroundServiceType=systemExempted (T-2-03) — startForeground не роняет приложение на Android 14+
- [Phase 02]: 02-02: android.R.drawable.stat_sys_vpn_ic (RESEARCH-пример) не публичный ресурс → заменён на android.R.drawable.ic_lock_lock (проверен по android.jar); VpnNotificationFactory.NOTIFICATION_ID=1001 для startForeground сервиса плана 03
- [Phase ?]: 02-03: OkoVpnService маршрутит только узкую подсеть 10.111.222.0/24 (addRoute), не 0.0.0.0/0 — интернет жив в Connected, счётчики через ping в подсеть (locked decision)
- [Phase ?]: 02-03: establish()==null и невалидный host/port → терминальный Error (не Disconnected) с ErrorMessage + stopForeground + stopSelf (T-2-04); userId не читается и не логируется (T-2-05)
- [Phase ?]: 02-03: единый @Synchronized teardown из ACTION_DISCONNECT/onRevoke/onDestroy — close(fd) ДО join потока (разблокирует блокирующий read, Pitfall 7), идемпотентен по Disconnected
- [Phase 02]: 02-05: harness читает трафик через AppDependencies.watchTraffic() (проброс vpnRepository); StreamBuilder<TrafficStats> readout rx/tx под статусом — AND-05 наблюдаем без Phase 3 UI
- [Phase 03]: 03-01: статичные .ttf инстансированы из variable-шрифтов google/fonts через fonttools varLib.instancer (fonts.google.com/download отдаёт HTML, репозиторий содержит только variable-фонты)
- [Phase 03]: 03-01: google_fonts матчит офлайн-бандл по имени файла {Family}-{Weight}.ttf; вес задаётся OS/2.usWeightClass, внутренний name-table игнорируется (Pitfall 5)
- [Phase 03]: 03-02: VpnStatus в core/theme (не feature) — accentFor это метод темы; Bloc и виджеты импортируют enum из core (feature→core законно)
- [Phase 03]: 03-02: ColorScheme обеих тем выведен из токенов OkoTones (single source, не fromSeed); литералы только void #0B0F14 / светлый фон #F4F6F9 / белый — scaffold вне токенов
- [Phase 03]: 03-02: типографика google_fonts поверх Typography.material2021() — цвета текста от режима темы; табличные цифры на displayLarge+titleMedium (таймер и числа трафика)
- [Phase 03]: 03-04: plainText форматирует время через приватный _hms (DateTime→HH:mm:ss), отдельно от hhmmss(Duration)
- [Phase 03]: 03-04: форматтеры байт/длительности — чистые top-level функции в presentation/formatters под unit-тест
- [Phase 03]: IrisIndicator принимает VpnStatus + connectedSince (презентационный, Bloc не читает); центр отдаёт в ConnectionTimer только в connected — Экран 03-08 обернёт в BlocBuilder; виджеты остаются переиспользуемыми и тестируемыми без Bloc
- [Phase 03]: reduce-motion читается в didChangeDependencies; oneShot-флаг отделяет смену статуса от смены зависимостей (тема/reduce не перезапускают раскрыв/shake/haptics) — Pitfall 3: MediaQuery недоступна в initState; повторный запуск одноразовых эффектов на rebuild — визуальный дефект
- [Phase 03]: 03-06: StatusBadge рендерит слово статуса title-case ('Disconnected') — behavior-контракт find.text приоритетнее косметического uppercase UI-SPEC; вид даёт стиль labelSmall
- [Phase 03]: 03-06: ConnectButton — StatelessWidget, бегущий сегмент в приватном _RunningSegment (уважает disableAnimations); спиннеры запрещены, прогресс через CustomPainter
- [Phase 03]: 03-06: foreground filled-кнопки = colorScheme.onPrimary (инверсия по яркости темы), не литерал void-цвета — контраст в обеих темах и проходит grep-гейт Color(0xFF
- [Phase 03]: 03-07: цвет уровня в root TextSpan (info/warning/error), время всегда secondary отдельным спаном
- [Phase 03]: 03-07: LogConsole использует выданный DraggableScrollableSheet-контроллер и для ListView, и для animateTo (Pattern 8)
- [Phase 04]: 04-01: ClipboardSource-абстракция в domain/repositories (не data) — presentation зависит только от domain per CONVENTIONS; SystemClipboardSource придёт в 04-02
- [Phase 04]: 04-01: parseVless — чистая функция String→sealed VlessParseResult поверх Uri.parse; ручная валидация диапазона порта 1..65535 (Uri не валидирует) и uuid-regex; fragment через decodeComponent, queryParameters не редекодятся
- [Phase 04]: 04-04: ServerConfigLoaded несёт latency nullable-полем — карточка рендерит конфиг сразу, задержка доезжает вторым emit
- [Phase 04]: 04-04: uuid не выносится в поле state, живёт внутри VlessConfig; маскирует карточка (T-4-02)
- [Phase 04]: 04-05: VpnHomeScreen рисует VlessConfigCard реактивно через BlocBuilder<ServerConfigCubit> (не context.read, Pitfall 4); карточка+кнопка внутри существующего _Staggered, staggered-анимация фазы 3 не тронута
- [Phase 04]: 04-05: вставленный vless-конфиг display-only — VpnConnectionBloc.config остаётся demoConfig, в реальный Connect не проводится (T-4-02b, Open Q1)
- [Phase 05]: 05-01: Embed App Extensions переставлена перед Thin Binary (build_phases.move) — снимает dependency-cycle Flutter build + app-extension; NE-таргет добавлен идемпотентным xcodeproj-скриптом, не ручной правкой pbxproj
- [Phase 05]: 05-01: entitlement packet-tunnel-provider + App Group group.com.example.vpnOko у обоих таргетов (Runner+PacketTunnel); Info.plist NSExtensionPointIdentifier com.apple.networkextension.packet-tunnel (без -provider); bundle id com.example.vpnOko.PacketTunnel
- [Phase ?]: 05-02: echo VpnHostApiImpl заменён реальным NETunnelProviderManager (load→save→loadFromPreferences reload→startVPNTunnel); честный симулятор-путь connecting→error+лог доказывает живой менеджер
- [Phase ?]: 05-02: VpnStatusObserver (NEVPNStatusDidChange) доводит NEVPNStatus до Flutter только через VpnEventListener.emit (main queue); runtime-демо/реальные переходы — device-checkpoint 05-03 (packet-tunnel NE appex не ставится на симулятор)

### Pending Todos

None yet.

### Blockers/Concerns

- ~~Phase 2: решение по маршруту~~ — снято: пользователь выбрал узкую подсеть (2026-07-13)
- Phase 5: источник живых статусов в Swift-слое при туннеле без core решить при планировании фазы (см. research Gaps); фаза помечена research-флагом
- ~~Phase 1: генерация Kotlin StreamHandler в pigeon 27.x~~ — снято (2026-07-13, план 01-01): pigeon 27.1.1 сгенерировал VpnEventsStreamHandler на Kotlin и Swift; @FlutterApi-fallback не нужен
- Дедлайн 48 часов: дифференциаторы Phase 6 добавляются по остатку времени, каждый независим и отбрасываем

## Deferred Items

Items acknowledged and carried forward from previous milestone close:

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| *(none)* | | | |

## Session Continuity

Last session: 2026-07-14T02:49:40.974Z
Stopped at: Completed 05-01-PLAN.md
Resume file: None
