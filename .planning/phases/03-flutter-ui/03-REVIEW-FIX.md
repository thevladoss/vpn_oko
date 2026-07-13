---
phase: 03-flutter-ui
fixed_at: 2026-07-14T00:00:00Z
review_path: .planning/phases/03-flutter-ui/03-REVIEW.md
iteration: 1
findings_in_scope: 8
fixed: 6
skipped: 2
status: partial
---

# Phase 3: Отчёт о правках код-ревью

**Источник ревью:** `.planning/phases/03-flutter-ui/03-REVIEW.md`
**Итерация:** 1

**Сводка:**
- Находок в scope: 8
- Исправлено: 6 (H-01, M-01, M-02, L-01, L-04, L-05)
- Не менялось кодом: 2 (L-02 — зафиксирована намеренность; L-03 — пропущена как рискованная)

**Гейты:**
- `flutter analyze` — No issues found
- `flutter test` — All tests passed (106)
- `flutter build apk --debug` — собран `build/app/outputs/flutter-apk/app-debug.apk`

## Исправленные находки

### H-01: Автоскролл логов зависает в паузе при всплеске событий

**Файлы:** `lib/features/vpn_logs/presentation/widgets/log_console.dart`, `test/features/vpn_logs/presentation/widgets/log_console_test.dart`
**Коммит:** df5b69b
**Правка:** `NotificationListener` теперь вызывает `_syncAutoScroll` только на `UserScrollNotification` и игнорирует `ScrollUpdateNotification` от программного `animateTo`. Пакетная подача логов в момент connect больше не ставит паузу посреди анимации. Добавлены два виджет-теста: всплеск из 240 записей держит `autoScroll = true`; пользовательский drag от низа ставит паузу.

### M-01: rx/tx-счётчики не сбрасываются при переходах статуса

**Файлы:** `lib/features/vpn_connection/presentation/bloc/vpn_connection_bloc.dart`, `test/features/vpn_connection/presentation/bloc/vpn_connection_bloc_test.dart`
**Коммит:** 71650f0
**Правка:** `_map` передаёт `rxBytes: 0, txBytes: 0` в ветках `VpnConnecting` и `VpnDisconnected`. `copyWith` уже принимает `int?` и корректно применяет ноль, дополнительной правки сигнатуры не требуется. Панель трафика не показывает байты прошлой сессии после disconnect и до первого `TrafficChanged` при reconnect. Добавлен blocTest на обнуление из seed rx=999/tx=888.

### M-02: VpnStarted не идемпотентен — повторный dispatch течёт подписками

**Файлы:** `lib/features/vpn_connection/presentation/bloc/vpn_connection_bloc.dart`, `test/features/vpn_connection/presentation/bloc/vpn_connection_bloc_test.dart`
**Коммит:** c8366b6
**Правка:** `_onStarted` отменяет `_stateSub`/`_trafficSub` перед пересозданием. Повторный `VpnStarted` не оставляет висящую подписку. Добавлен тест: первый набор контроллеров теряет слушателя после второго `VpnStarted`, второй активен и закрывается в `close()`.

### L-01: hhmmss некорректно рендерит отрицательную длительность

**Файлы:** `lib/features/vpn_connection/presentation/formatters/duration_format.dart`, `test/features/vpn_connection/presentation/timer_format_test.dart`
**Коммит:** 5c7cfb3
**Правка:** Отрицательная длительность приводится к `Duration.zero` в начале форматтера (через локальную переменную, без присваивания параметру). `Duration(seconds: -1)` даёт `00:00:00`. Добавлен тест на отрицательные значения.

### L-04: TrafficTile жёстко завязан на формат вывода formatBytes

**Файлы:** `lib/features/vpn_connection/presentation/formatters/byte_format.dart`, `lib/features/vpn_connection/presentation/widgets/traffic_tile.dart`, `test/features/vpn_connection/presentation/format_bytes_test.dart`
**Коммит:** 07f87c9
**Правка:** Добавлена `formatBytesParts(int) -> (String value, String unit)`; `formatBytes` переиспользует её. `TrafficTile` берёт число и единицу из записи напрямую, `lastIndexOf`/`substring` убраны — риск `RangeError` исключён. Добавлены тесты на `formatBytesParts` и согласованность с `formatBytes`.

### L-05: Повсеместный force-unwrap extension<OkoTones>()!

**Файлы:** `lib/core/theme/oko_tones.dart` + 10 виджетов/экран, `test/core/theme/oko_tones_test.dart`
**Коммит:** cf79b63
**Правка:** Введён `extension OkoTonesContext on BuildContext { OkoTones get okoTones }` с `assert`-контрактом. Десять точек `Theme.of(context).extension<OkoTones>()!` заменены на `context.okoTones`, единственная точка отказа централизована. Добавлен виджет-тест хелпера.

## Не изменялось кодом

### L-02: AppDependencies.dispose() определён, но не вызывается

**Файл:** `lib/app/di.dart:50-54`, `lib/main.dart`
**Решение:** намеренно оставлено без правки кода.
**Обоснование:** `AppDependencies` — единственный инстанс на весь процесс, `dispose()` избыточен при штатном завершении. Проектная конвенция запрещает комментарии в коде, поэтому пояснение зафиксировано здесь, а не в исходнике. `dispose()` сохранён как контракт для тестов с реальным DI и на случай будущего пересоздания `OkoApp`. Автоматическая привязка через `AppLifecycleListener` даёт платформенно-ненадёжный `onDetach` и риск закрытия моста при возможном resume на Android — цена выше латентной пользы. Пересмотреть при появлении сценария с несколькими инстансами DI.

### L-03: _onStarted — подписка после await и перехват только Failure

**Файл:** `lib/features/vpn_connection/presentation/bloc/vpn_connection_bloc.dart:47-61`
**Решение:** пропущено (по границам задачи — рискованно).
**Обоснование:** Перенос `listen` до `await syncStatus()` меняет порядок эмиссии начального статуса/трафика и способен сдвинуть ожидаемые последовательности состояний в blocTest-сценариях 1-6. Текущие data-стримы (broadcast с текущим значением) событие не теряют. Расширение `catch` до generic-исключения меняет контракт обработки ошибок слоя data. Обе части выходят за безопасный объём presentation-правок фазы 3.

---

_Fixed: 2026-07-14_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
