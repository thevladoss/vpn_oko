# Plan 02-06 Summary — Живой device-чеклист Android VpnService

**Plan:** 02-06 (checkpoint:human-verify — реальный туннель на эмуляторе API 34+)
**Status:** complete (прогнано оркестратором на эмуляторе)
**Requirements:** AND-01, AND-02, AND-03, AND-04, AND-05, AND-06
**Self-Check:** PASSED

## Окружение
- Android-эмулятор Medium_Phone_API_36.1 (API 36), поднят с `-wipe-data -partition-size 4096` (после нехватки места ранее).
- Приложение установлено и запущено через `flutter run -d emulator-5554`, взаимодействие через `adb shell input tap` + `screencap`, наблюдение через `logcat`/`dumpsys`.
- Физическое устройство Vivo V2061 в списке adb НЕ трогалось (все команды с `-s emulator-5554`).

## Результаты чеклиста (все пункты пройдены вживую)

| # | Проверка | Req | Результат (доказательство) |
|---|----------|-----|----------------------------|
| 1 | Consent → Connected | AND-01, AND-02 | Echo Connect → системный диалог «Connection request: vpn_oko wants to set up a VPN…» → OK → Status: **Connected since 2026-07-13 23:41:54**, значок 🔑 в статус-баре |
| 2 | Реальный туннель, узкий маршрут | AND-02 | logcat: `Established by com.example.vpn_oko on tun0`; `Address added on tun0: 10.0.0.2`; **Routes: `10.111.222.0/24 -> tun0`** (не 0.0.0.0/0 — интернет устройства жив); DNS `1.1.1.1`; система метит сеть `IS_VPN` |
| 3 | FGS + уведомление + systemExempted, нет краша | AND-03 | `dumpsys notification`: `id=1001 channel=oko_vpn flags=ONGOING_EVENT\|NO_CLEAR\|FOREGROUND_SERVICE`; POST_NOTIFICATIONS runtime-диалог показан и разрешён; краша MissingForegroundServiceType/DidNotStartInTime нет |
| 4 | Счётчик трафика rx | AND-05 | UI: **rx: 200 B** — read-loop реально прочитал байты из TUN fd и отдал через trafficChanged (1Гц ticker). Прирост зависит от роутинга: узкий маршрут пускает через tun0 только 10.111.222.0/24 |
| 5 | Отказ consent → Error | AND-01 | Отозвал разрешение (`appops ACTIVATE_VPN deny`) → Connect → диалог → Cancel → Status: **Error: unknown** + лог **[error] VPN permission denied** (Error, не Disconnected — по SC#1) |
| 6 | Disconnect teardown | AND-04 | Echo Disconnect → Status: Disconnected, 🔑 исчез; logcat `setting state=DISCONNECTED, reason=agentDisconnect`; логи `state → DISCONNECTING → stopped by user → DISCONNECTED` |
| 7 | Стабильность lifecycle ×3 | AND-03, AND-04 | 3 полных цикла establish→teardown в логах (`Established … on tun0` ↔ `DISCONNECTED, reason=agentDisconnect`); ни одного FATAL/ConcurrentModification — патч потокобезопасности VpnEventBus держит многопоточный emit |
| 8 | Все переходы логируются | AND-06 | Каждый переход виден в UI-логах через logMessage: CONNECTING → CONNECTED → DISCONNECTING → DISCONNECTED |

## Требования — вердикт
- **AND-01** ✅ consent OK→Connected и Cancel→Error проверены вживую
- **AND-02** ✅ establish на узкую подсеть, интернет-маршрут не перехвачен (route 10.111.222.0/24→tun0)
- **AND-03** ✅ FGS-уведомление (systemExempted), POST_NOTIFICATIONS, нет краша на API 36
- **AND-04** ✅ teardown по Disconnect (стабильно ×3)
- **AND-05** ✅ rx считается из реального TUN read-loop (rx>0)
- **AND-06** ✅ все переходы логируются

## Не воспроизведено вживую (зафиксировано честно)
- **onRevoke через второй VPN**: требует установки второго VPN-приложения, перехватывающего туннель. В окружении второго VPN нет. `onRevoke()` вызывает тот же единый `teardown()`, что проверен вживую через Disconnect (закрытие fd → stopForeground → Disconnected), и приходит НЕ на main thread — доставка событий через потокобезопасный VpnEventBus + main-thread VpnEventListener. Ветка покрыта кодом и симметрична проверенному пути; сам триггер onRevoke не инициирован.

## Мелкое наблюдение (для Phase 3 UI / будущего)
- При отказе consent статус показывает «Error: **unknown**» — код ошибки не заполняется (StatusChangedMessage(ERROR) без кода), хотя лог несёт внятную причину «VPN permission denied». Для Phase 3 UI стоит показывать сообщение из лога/ошибки, а не код. AND-01 удовлетворён (Error + внятный лог).

## Итог
Реальный Android VpnService поднимается через consent, живёт в foreground-сервисе с systemExempted-уведомлением, считает трафик из TUN read-loop, корректно завершается и логирует все переходы — цель фазы 2 (главный критерий «сильного решения» ТЗ) достигнута и подтверждена на устройстве. Скриншоты: p2_consent, p2_connected, p2_conn3, p2_rx, p2_disc, p2_error, p2_final в scratchpad сессии.
