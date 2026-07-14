# Plan 04-06 Summary — Phase-gate VLESS (автотест + device-проверка)

**Plan:** 04-06 (автотест-gate + checkpoint:human-verify device)
**Status:** complete (автогейт зелёный; device-проводка подтверждена, валидный путь test-covered)
**Requirements:** VLS-01, VLS-02, VLS-03, QA-01
**Self-Check:** PASSED

## Task 1 — автотест-gate
- `flutter analyze` — No issues found
- `flutter test` — 138/138 зелёные (парсер 11 кейсов QA-01, probe с фейком, cubit blocTest, карточка widget с маскировкой uuid)
- `flutter build apk --debug` — собран

## Task 2 — device-проверка (эмулятор API 36)

### Подтверждено вживую
- Кнопка **«Вставить vless://»** встроена в VpnHomeScreen между карточкой Echo Server и плитками трафика, стилизована под тему (dark pill + clipboard icon) — интеграция VLS-02 на экране работает.
- Тап кнопки при пустом буфере → реактивно показал ошибку **«Буфер пуст»** коралловым над кнопкой. Это доказывает живую проводку VLS-02 end-to-end: `PasteConfigButton.onPressed → context.read<ServerConfigCubit>().pasteFromClipboard() → ClipboardSource.readText() (пусто) → emit Error(empty) → describeVlessError → BlocBuilder перерисовал экран`.

### Не прогнано вживую (ограничение окружения)
- **Валидная вставка vless://-ссылки** визуально не показана: установить Android-буфер валидной строкой через adb в этом headless-окружении надёжно нельзя (`cmd clipboard` недоступен на образе; clipper-broadcast требует helper-приложения; host→guest sync требует фокуса окна эмулятора, недостижимого из скрипта). Это ограничение инструментария, не кода.
- **Валидный путь полностью покрыт зелёными тестами:**
  - `vless_parser_test.dart` — 11 edge-case кейсов (reality/tcp, ws/tls, grpc, percent-encoded, IPv6, порт вне диапазона, нечисловой порт, битый uuid, пустой host, чужая схема, trim, дефолты) — VLS-01, QA-01.
  - `server_config_cubit_test.dart` — paste valid → Loaded(config), затем Loaded(config, latency); paste invalid → Error(reason); пустой буфер → Error(empty) — VLS-02.
  - `vless_config_card_test.dart` — карточка рендерит поля, **маскирует uuid** (полная строка и хвост дают findsNothing, маска findsOneWidget), LatencyMeasured/Unreachable — VLS-02.
  - `socket_latency_probe_test.dart` — measured RTT через фейк-connector; SocketException → LatencyUnreachable — VLS-03.
- На демо пользователь подставит реальную vless://-ссылку в буфер (реальную ссылку он даёт ближе к демо), карточка отрисуется и tcping (реальный `Socket.connect` в SocketLatencyProbe) измерит задержку к реальному хосту.

## Требования — вердикт
- **VLS-01** ✅ парсер vless://→VlessConfig, 11 кейсов (unit)
- **VLS-02** ✅ вставка из буфера + реактивная карточка; проводка live-verified (error path на устройстве), валидный путь test-covered
- **VLS-03** ✅ tcping через Socket.connect+Stopwatch (unit с фейком; реальный Socket на устройстве)
- **QA-01** ✅ 11 edge-case тестов парсера зелёные

## Итог
Пользователь может вставить vless://-ссылку из буфера и увидеть карточку сервера с задержкой — фича собрана, интеграция в экран live-verified, парсер/tcping/cubit/карточка покрыты 138 зелёными тестами, ноль новых пакетов, uuid маскируется. Цель фазы 4 достигнута. Скриншоты: p4_before (кнопка вставки), p4_paste1 (Буфер пуст error path) в scratchpad.
