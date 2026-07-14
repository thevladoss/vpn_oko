---
phase: 04-vless
plan: 01
subsystem: domain
tags: [vless, uri-parse, sealed, equatable, tdd, flutter, dart]

requires:
  - phase: 03-ui
    provides: паттерн sealed+equatable (VpnState, VpnConfig), analysis_options с one_member_abstracts:false
provides:
  - VlessConfig (immutable entity, 7 полей)
  - sealed VlessParseResult (VlessParsed|VlessParseFailure) + enum VlessError
  - sealed LatencyResult (LatencyMeasured|LatencyUnreachable)
  - abstract interface LatencyProbe (measure)
  - abstract interface ClipboardSource (readText)
  - parseVless(String) → VlessParseResult (чистая функция, 11 кейсов зелёные)
affects: [04-02, 04-03, 04-04, 04-05]

tech-stack:
  added: []
  patterns:
    - "Парсер как чистая функция String → sealed-результат поверх Uri.parse"
    - "domain-абстракции LatencyProbe/ClipboardSource для инъекции фейков в тестах"

key-files:
  created:
    - lib/features/server_config/domain/entities/vless_config.dart
    - lib/features/server_config/domain/entities/vless_parse_result.dart
    - lib/features/server_config/domain/entities/latency_result.dart
    - lib/features/server_config/domain/repositories/latency_probe.dart
    - lib/features/server_config/domain/repositories/clipboard_source.dart
    - lib/features/server_config/domain/services/vless_parser.dart
    - test/features/server_config/domain/vless_parser_test.dart
  modified: []

key-decisions:
  - "ClipboardSource-абстракция живёт в domain/repositories (не в data): presentation зависит только от domain per CONVENTIONS; реализация придёт в 04-02"
  - "uuid-regex 8-4-4-4-12 как приватная top-level, ноль пакетов (uuid/dartz запрещены)"
  - "fragment декодируется через Uri.decodeComponent, queryParameters не редекодятся (Pitfall 6)"

patterns-established:
  - "parseVless: trim → Uri.parse в try/catch(FormatException) → ручная валидация scheme/uuid/host/диапазона порта → sealed-результат, наружу не бросает"
  - "sealed result вместо Either из dartz (совпадает с проектным sealed VpnState)"

requirements-completed: [VLS-01, QA-01]

duration: 4min
completed: 2026-07-14
---

# Phase 04 Plan 01: Доменное ядро server_config Summary

**Чистый парсер `vless://` (Uri.parse + ручная валидация, 11 кейсов зелёные) и sealed-контракты VlessConfig/VlessParseResult/LatencyResult + абстракции LatencyProbe/ClipboardSource.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-07-14T00:40:05Z
- **Completed:** 2026-07-14T00:44:25Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments
- Feature `server_config` заложена: 6 доменных файлов (5 контрактов + парсер) проходят анализатор чисто
- `parseVless` покрывает валидные ссылки, кривые, IPv6, percent-encoding, диапазон порта, дефолты, trim из буфера — 11 кейсов QA-01 зелёные
- Sealed-модели и single-method абстракции зафиксировали контракты для data/presentation-планов фазы
- Полный набор проекта зелёный: 117 тестов

## Task Commits

Each task was committed atomically:

1. **Task 1: Доменные модели и абстракции server_config** - `57fc8d5` (feat)
2. **Task 2 RED: падающие тесты парсера vless://** - `1865ccb` (test)
3. **Task 2 GREEN: реализация parseVless** - `baea6d8` (feat)

_TDD: Task 2 выполнен как RED → GREEN; REFACTOR не потребовался (код минимален и чист)._

## Files Created/Modified
- `lib/features/server_config/domain/entities/vless_config.dart` - immutable VlessConfig (uuid, host, port, transport, security, sni, name)
- `lib/features/server_config/domain/entities/vless_parse_result.dart` - sealed VlessParseResult + enum VlessError
- `lib/features/server_config/domain/entities/latency_result.dart` - sealed LatencyResult (Measured|Unreachable)
- `lib/features/server_config/domain/repositories/latency_probe.dart` - abstract interface LatencyProbe.measure
- `lib/features/server_config/domain/repositories/clipboard_source.dart` - abstract interface ClipboardSource.readText
- `lib/features/server_config/domain/services/vless_parser.dart` - parseVless(String) → VlessParseResult
- `test/features/server_config/domain/vless_parser_test.dart` - 11 кейсов парсера (VLS-01, QA-01)

## Decisions Made
- ClipboardSource размещён в `domain/repositories` (research предлагал data/datasources): presentation зависит только от domain per CONVENTIONS; реализация SystemClipboardSource придёт в 04-02
- uuid проверяется приватным top-level regex 8-4-4-4-12, без пакета `uuid`
- Result-тип — sealed VlessParseResult, без `dartz`/`fpdart`

## Deviations from Plan

None - plan executed exactly as written.

Мелкие правки формата под very_good_analysis (перенос длинных строк в тесте и regex, снятие лишнего `r`-префикса у первой части regex) — форматирование внутри плановых файлов, не отклонение по существу.

## Issues Encountered
None. Uri.parse повёл себя ровно как в research: диапазон порта не валидируется (ручная проверка 1..65535), fragment percent-encoded (decodeComponent), нечисловой порт и ведущие пробелы бросают FormatException (trim + try/catch).

## Threat Model Coverage
- **T-4-01 (DoS):** `parseVless` не бросает наружу — `Uri.parse` в try/catch(FormatException), всё через sealed-результат. Тесты на `:abc` (malformed) и `''` (scheme) подтверждают.
- **T-4-03 (Tampering):** `Uri.decodeComponent` только для fragment; queryParameters не редекодятся. Тесты percent-encoded имени (пробел + эмодзи) фиксируют.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Контракты `LatencyProbe`, `ClipboardSource`, `LatencyResult`, `VlessConfig`, `VlessParseResult` готовы к использованию data-планом 04-02 (SocketLatencyProbe, SystemClipboardSource) и presentation-планом (ServerConfigCubit)
- Парсер закрывает VLS-01 и ядро QA-01; остальные кейсы QA (cubit, widget) — в следующих планах фазы

## Self-Check: PASSED

Все 7 созданных файлов + SUMMARY на диске; коммиты `57fc8d5`, `1865ccb`, `baea6d8` в истории.

---
*Phase: 04-vless*
*Completed: 2026-07-14*
