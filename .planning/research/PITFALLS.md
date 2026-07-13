# Pitfalls Research

**Domain:** Flutter VPN-прототип с нативной интеграцией (Android VpnService, iOS Network Extension, Pigeon)
**Researched:** 2026-07-13
**Confidence:** HIGH (Android/Flutter/Pigeon подтверждены официальными доками; iOS NE подтверждён Apple docs + community)

## Critical Pitfalls

### Pitfall 1: Consent-флоу `VpnService.prepare()` вызывается один раз или не обрабатывается отказ

**What goes wrong:**
`startVpn()` вызывает сервис без свежего consent. `establish()` возвращает `null` или бросает `SecurityException`, туннель не поднимается, UI зависает в Connecting. Второй вариант: пользователь нажимает Cancel в системном диалоге, а приложение не обрабатывает `RESULT_CANCELED` и остаётся в Connecting навсегда.

**Why it happens:**
Разработчики считают consent одноразовым. Официальная документация говорит обратное: «Only one app can be the current prepared VPN service. Always call `VpnService.prepare()` because a person might have set a different app as the VPN service since your app last called the method». Если пользователь запускал другой VPN (даже системный тест), prepared-статус вашего приложения сброшен.

**How to avoid:**
- Вызывать `prepare()` перед КАЖДЫМ стартом, не только при первом.
- `prepare()` вернул `null` → сразу стартовать сервис. Вернул `Intent` → `startActivityForResult` (ActivityResultLauncher).
- `RESULT_OK` → `startForegroundService`. `RESULT_CANCELED` → отправить в Flutter событие `error` + статус Disconnected. Никогда не оставлять Connecting без выхода.
- В Flutter-слое переходить в Connecting только после подтверждения от native, что consent получен и сервис стартует.

**Warning signs:**
`establish()` возвращает `null` в логах; кнопка Connect «ничего не делает» после того как на устройстве запускали другой VPN; UI застревает в Connecting после отмены диалога.

**Phase to address:**
Фаза Android VpnService (реализация start-флоу).

---

### Pitfall 2: `addRoute("0.0.0.0", 0)` без VPN-core убивает интернет на устройстве

**What goes wrong:**
Прототип честно вызывает `addRoute("0.0.0.0", 0)`, туннель поднимается, весь трафик устройства уходит в TUN-интерфейс. Ядра, которое читает пакеты и проксирует их, нет. Итог: в состоянии Connected устройство полностью теряет сеть. На видео-демо это выглядит как сломанное приложение, а не как «сильное решение».

**Why it happens:**
ТЗ просит `addRoute`, разработчик копирует «правильную» конфигурацию боевого VPN. Прототип без core не обслуживает перехваченный трафик.

**How to avoid:**
Два рабочих варианта, оба описать в README:
1. Маршрутизировать узкую тестовую подсеть (например `addRoute("10.111.222.0", 24)`): туннель реально поднят, значок ключа в статус-баре есть, интернет устройства не тронут. Для демо предпочтительно.
2. Роутить всё, но запустить поток, который читает пакеты из `ParcelFileDescriptor` и дропает их, при этом считать байты для `trafficChanged`. Интернета не будет, зато статистика трафика живая. Годится, если это явно проговорено в README и видео.

Решение зафиксировать до написания кода сервиса, оно влияет на источник данных `trafficChanged`.

**Warning signs:**
После Connect на устройстве перестаёт открываться любой сайт; Chrome показывает «нет соединения» при активном туннеле.

**Phase to address:**
Фаза Android VpnService (конфигурация Builder) + фаза документации (README-объяснение).

---

### Pitfall 3: События в Flutter отправляются с фонового потока → crash `@UiThread`

**What goes wrong:**
Сервис шлёт `statusChanged`/`logMessage` из рабочего потока (поток чтения TUN, коллбек `onRevoke`). Приложение падает: «Methods marked with @UiThread must be executed on the main thread» (Android) или получает undefined behavior на iOS.

**Why it happens:**
Два фактора накладываются. Первый: Flutter требует вызывать канал в сторону Dart только с main thread платформы (официально: «When invoking channels on the platform side destined for Flutter, invoke them on the platform's main thread»). Второй: `onRevoke()` по документации «might not happen on the main thread», то есть система сама вызывает ваш код с произвольного потока. Pigeon-генерированный `EventSink`/`FlutterApi` этого не скрывает.

**How to avoid:**
Единая точка отправки событий в native-слое (класс-эмиттер), внутри которой каждый вызов sink/callback обёрнут в `Handler(Looper.getMainLooper()).post { }` (Kotlin) и `DispatchQueue.main.async { }` (Swift). Запретить прямые вызовы sink из сервиса.

**Warning signs:**
Крэш при revoke или при остановке из шторки уведомлений при том, что Connect/Disconnect с кнопки работают (кнопка идёт через main thread, коллбеки системы нет).

**Phase to address:**
Фаза Pigeon bridge (эмиттер событий проектируется вместе с мостом).

---

### Pitfall 4: Race «сервис уже шлёт события, а Dart-слушатель ещё не подписан»

**What goes wrong:**
Сервис отправляет `statusChanged(CONNECTED)` раньше, чем Flutter-сторона подписалась на event channel (холодный старт, hot restart, возврат приложения из фона при живом VPN). Событие теряется, UI показывает Disconnected при работающем туннеле. Hot restart во время разработки убивает Dart-подписки, но не native-сервис, и рассинхрон воспроизводится постоянно.

**Why it happens:**
Event channel доставляет события только активному подписчику, буфера на native-стороне нет. FlutterEngine и сервис живут независимыми жизненными циклами.

**How to avoid:**
- Native хранит последний статус в синглтоне/companion object.
- Pigeon-метод `getStatus()` возвращает снапшот: статус + `connectedSince` + счётчики трафика.
- Flutter вызывает `getStatus()` при каждом старте приложения и при resume, до отрисовки экрана, затем подписывается на поток.
- В `onListen` StreamHandler'а сразу реплеить текущий статус новому подписчику. Это закрывает и hot restart.

**Warning signs:**
После hot restart UI показывает Disconnected при значке ключа в статус-баре; статус «прыгает» при сворачивании/разворачивании приложения.

**Phase to address:**
Фаза Pigeon bridge (контракт `getStatus()` со снапшотом) + фаза Flutter UI (вызов при старте/resume).

---

### Pitfall 5: Android 14: не объявлен `foregroundServiceType` → crash при `startForeground()`

**What goes wrong:**
На targetSdk 34+ вызов `startForeground()` без объявленного типа роняет сервис (`MissingForegroundServiceTypeException`). Второй сценарий: разработчик выбирает `specialUse` «на всякий случай», хотя для VPN есть точный тип.

**Why it happens:**
Требование появилось в Android 14 и не срабатывает на старых эмуляторах, поэтому его замечают поздно. Документация Android явно относит VPN-приложения к типу `systemExempted`: список допущенных к этому типу включает «VPN apps (configured using Settings > Network & Internet > VPN)». Для остальных приложений `systemExempted` бросает `ForegroundServiceTypeNotAllowedException`, отсюда путаница.

**How to avoid:**
В манифесте:
```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_SYSTEM_EXEMPTED" />

<service
    android:name=".OkoVpnService"
    android:permission="android.permission.BIND_VPN_SERVICE"
    android:foregroundServiceType="systemExempted"
    android:exported="false">
    <intent-filter>
        <action android:name="android.net.VpnService" />
    </intent-filter>
</service>
```
В `startForeground()` передавать `FOREGROUND_SERVICE_TYPE_SYSTEM_EXEMPTED` (перегрузка с типом). `specialUse` не использовать: он требует `PROPERTY_SPECIAL_USE_FGS_SUBTYPE` и ревью в Play Console, а для VpnService есть легальный `systemExempted`.

**Warning signs:**
Крэш только на API 34+ эмуляторе/устройстве при старте сервиса; на API 33 всё работает.

**Phase to address:**
Фаза Android VpnService (манифест + foreground-обвязка), проверка на API 34/35 эмуляторе.

---

### Pitfall 6: Android 13+: уведомление Foreground Service невидимо без `POST_NOTIFICATIONS`

**What goes wrong:**
Сервис работает, `startForeground()` вызван, но на Android 13+ уведомление не появляется в шторке: runtime-permission `POST_NOTIFICATIONS` никто не запросил. Требование ТЗ «Foreground Service с уведомлением» на видео-демо показать нечем.

**Why it happens:**
FGS не падает без разрешения на уведомления, он просто молча работает (виден только в системном Task Manager). Ошибки нет, поэтому проблему замечают на этапе записи демо.

**How to avoid:**
- `<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />` в манифест.
- Запрашивать разрешение при первом нажатии Connect, до/параллельно с VPN-consent (два системных диалога подряд: сначала уведомления, потом VPN).
- Канал уведомлений создавать до `startForeground()`, важность `IMPORTANCE_LOW`, `setOngoing(true)`.
- Отказ в разрешении не блокирует VPN: сервис стартует в любом случае, лог-событие в Flutter фиксирует отсутствие уведомления.

**Warning signs:**
Уведомления нет в шторке на API 33+, при этом на API 32 эмуляторе есть.

**Phase to address:**
Фаза Android VpnService (permissions-флоу перед стартом).

---

### Pitfall 7: `onRevoke()` не обработан: другой VPN перехватил туннель, UI показывает Connected

**What goes wrong:**
Пользователь включает другой VPN (или отключает через системные настройки). Система вызывает `onRevoke()`, интерфейс уже мёртв, но приложение продолжает показывать Connected, уведомление висит, fd течёт.

**Why it happens:**
`onRevoke()` легко пропустить: на happy path он не вызывается. Документация: «When the system calls this method, an alternative network interface is already routing traffic», то есть к моменту вызова туннель уже отобран, спорить поздно.

**How to avoid:**
В `onRevoke()` выполнить полный teardown: закрыть `ParcelFileDescriptor` (`close()`, дренировать не нужно), остановить рабочие потоки, `stopForeground(STOP_FOREGROUND_REMOVE)`, `stopSelf()`, отправить в Flutter `statusChanged(DISCONNECTED)` + `logMessage("revoked by system")` через main-thread эмиттер (см. Pitfall 3: onRevoke приходит не с main thread). Teardown вынести в один метод, переиспользуемый из `stopVpn()`, `onRevoke()` и `onDestroy()`.

**Warning signs:**
После включения второго VPN-приложения ваш UI остаётся зелёным; уведомление не исчезает после revoke.

**Phase to address:**
Фаза Android VpnService (lifecycle). Тест руками: включить «другой VPN» (любое VPN-приложение из Play или второй ваш билд) поверх работающего.

---

### Pitfall 8: Утечки `ParcelFileDescriptor` и незакрываемый blocking read

**What goes wrong:**
Поток читает TUN через блокирующий `read()`. `Thread.interrupt()` его не прерывает, поток живёт вечно, fd не закрывается. При повторном Connect копятся зомби-потоки и fd, через несколько циклов connect/disconnect сервис ведёт себя непредсказуемо.

**Why it happens:**
Блокирующий I/O на file descriptor не реагирует на interrupt. Разработчики пишут `thread.interrupt()` и считают дело сделанным.

**How to avoid:**
- Порядок остановки: сначала `pfd.close()` (read() тут же вернёт ошибку и поток выйдет), потом join потока с таймаутом.
- `pfd` хранить в одном месте, обнулять после close, закрывать в `try/finally`.
- Каждый `establish()` предваряется закрытием предыдущего pfd, если он есть.
- Для прототипа без core: если выбран вариант «читать и дропать» (Pitfall 2), тот же порядок обязателен.

**Warning signs:**
`StrictMode` ругается на unclosed resources; повторный Connect после Disconnect работает через раз; в логах несколько живых read-потоков.

**Phase to address:**
Фаза Android VpnService (teardown-логика).

---

### Pitfall 9: VPN-сервис в отдельном процессе ломает Pigeon-мост

**What goes wrong:**
По примеру боевых клиентов (v2rayNG, sing-box кладут VpnService в `android:process=":vpn"`) сервис уезжает в отдельный процесс. FlutterEngine и Pigeon-каналы живут в основном процессе, синглтон со статусом в процессе сервиса невидим для моста. События «отправляются», но не доходят; `getStatus()` возвращает пустоту.

**Why it happens:**
Отдельный процесс защищает боевой VPN от смерти UI-процесса и утечек памяти core. Для прототипа с Pigeon это преждевременная оптимизация, ломающая главный критерий ТЗ (живые события в Flutter).

**How to avoid:**
Не указывать `android:process` у сервиса: один процесс, общая память, Pigeon-эмиттер и синглтон статуса работают напрямую. В README (раздел «план интеграции core») честно указать: при подключении реального core сервис стоит выносить в отдельный процесс, и тогда мост дополняется IPC (Messenger/AIDL) между процессами.

**Warning signs:**
События из сервиса не приходят в Flutter, при этом логи native показывают их отправку; статус в UI всегда Disconnected.

**Phase to address:**
Фаза Android VpnService (решение зафиксировать в манифесте) + фаза документации.

---

### Pitfall 10: `startForeground()` вызван слишком поздно после `startForegroundService()`

**What goes wrong:**
Activity стартует сервис через `startForegroundService()`, а сервис вызывает `startForeground()` после «тяжёлой» инициализации (prepare конфига, establish). Система убивает приложение: `ForegroundServiceDidNotStartInTimeException` (лимит порядка 5 секунд).

**Why it happens:**
Кажется логичным показать уведомление «Connected» только после успешного establish. Система требует уведомление сразу после старта сервиса.

**How to avoid:**
Первой строкой `onStartCommand()` вызвать `startForeground()` с уведомлением «Connecting…», после establish обновить то же уведомление текстом «Connected». Обновление содержимого уведомления дешёвое, повторный `notify()` с тем же id.

**Warning signs:**
Редкие крэши при старте на медленных эмуляторах; crash log с `DidNotStartInTime`.

**Phase to address:**
Фаза Android VpnService (порядок вызовов в onStartCommand).

---

### Pitfall 11: iOS: Network Extension не работает в симуляторе и не собирается под personal team

**What goes wrong:**
Три отдельных провала. Первый: попытка продемонстрировать PacketTunnelProvider в симуляторе; NE-провайдеры на симуляторе не запускаются в принципе, любые вызовы падают с permission denied. Второй: extension-target добавлен в схему запуска, и `flutter run` на iOS перестаёт собираться из-за подписи extension (personal/free team не может включить capability Network Extensions). Третий: entitlements (`com.apple.developer.networking.networkextension` со значением `packet-tunnel-provider`) прописаны только у app или только у extension; нужно у обоих.

**Why it happens:**
NE-ограничения не видны, пока не откроешь Xcode: Flutter-разработчики ожидают, что «skeleton» соберётся как обычный код.

**How to avoid:**
- Цель фазы: «extension-target компилируется», а не «туннель запускается». Проверка: `xcodebuild build` таргета extension проходит.
- Не включать extension в embedded binaries debug-конфигурации, если подпись недоступна, либо документировать требование платного Apple Developer аккаунта.
- В README отдельно: NE тестируется только на физическом устройстве; для связи app ↔ extension нужен общий App Group (`group.<bundle-id>`) у обоих таргетов; конфиг передаётся через `NETunnelProviderProtocol.providerConfiguration` или shared UserDefaults App Group.
- Skeleton `PacketTunnelProvider` реализует `startTunnel(options:completionHandler:)` и `stopTunnel(with:completionHandler:)` с `NEPacketTunnelNetworkSettings` и вызовом completionHandler, чтобы код был честным, а не пустым.

**Warning signs:**
`flutter run` на iOS падает с ошибкой подписи после добавления extension; «Profile doesn't support Network Extensions» в Xcode.

**Phase to address:**
Фаза iOS skeleton (последняя из платформенных, чтобы не блокировать Android-демо).

---

### Pitfall 12: Pigeon: event channels доступны не во всех генераторах, sink требует main thread

**What goes wrong:**
Первое: `@EventChannelApi` генерируется только для Swift, Kotlin и Dart (официально: «Event channels are supported only on the Swift, Kotlin, and Dart generators»); попытка сгенерировать Java/ObjC-выход для событий провалится. Второе: сгенерированный StreamHandler не решает threading, события из фонового потока роняют приложение (см. Pitfall 3). Третье: все `@EventChannelApi`-определения должны жить корректно в конфигурации pigeon-входа; при нескольких input-файлах с event channels известны проблемы (flutter/flutter#161291).

**Why it happens:**
Pigeon воспринимают как «сгенерировал и забыл», а генератор закрывает сериализацию, но не потоки и не lifecycle подписок.

**How to avoid:**
- Один pigeon-входной файл (`pigeons/vpn_api.dart`) с HostApi (`startVpn`, `stopVpn`, `getStatus`) и EventChannelApi (события) вместе.
- Выходы: `kotlinOut` + `swiftOut` (не javaOut/objcOut). Зафиксировать версию pigeon (текущая 27.x) в dev_dependencies.
- Команду генерации положить в README/makefile: `dart run pigeon --input pigeons/vpn_api.dart`.
- Обёртка над sink с main-thread post (см. Pitfall 3).
- Альтернатива event channel: `@FlutterApi` коллбеки; у них то же требование main thread. Выбрать один механизм и не смешивать.

**Warning signs:**
Ошибка генерации при указании javaOut с EventChannelApi; крэши на событиях из сервиса; события перестают приходить после hot restart (лечится реплеем из Pitfall 4).

**Phase to address:**
Фаза Pigeon bridge (первая платформенная фаза: контракт до реализации сервисов).

---

### Pitfall 13: Таймер подключения живёт в Flutter-стейте и врёт после рестарта

**What goes wrong:**
Таймер стартует от нажатия Connect (`Stopwatch`/`Timer.periodic` в состоянии виджета). После hot restart, пересоздания приложения или свёртывания на длительное время таймер обнуляется или отстаёт, при том что VPN работает непрерывно. На демо это выглядит как баг статусов.

**Why it happens:**
Источник истины о времени подключения кладут в эфемерный Dart-стейт, а не рядом с фактом подключения (native-сервис).

**How to avoid:**
- Native фиксирует `connectedSince` (epoch millis) в момент успешного `establish()` и отдаёт его в снапшоте `getStatus()` и в событии `statusChanged(CONNECTED)`.
- Flutter каждый тик рендерит `now - connectedSince`, сам ничего не накапливает.
- Тикающий Timer в Dart только триггерит перерисовку; при статусах, отличных от Connected, таймер останавливается и поле скрывается/обнуляется.
- Переходы Connecting → Connected → Disconnecting: таймер запускается только по Connected, сбрасывается по Disconnected/Error.

**Warning signs:**
После hot restart таймер начинается с 00:00 при живом туннеле; таймер продолжает тикать в статусе Error.

**Phase to address:**
Фаза Flutter UI/state (модель VpnState с connectedSince) + контракт в фазе Pigeon bridge.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Узкий маршрут вместо 0.0.0.0/0 (Pitfall 2) | Демо с рабочим интернетом | Не демонстрирует «полный» перехват трафика | Для прототипа да, с явной пометкой в README |
| Сервис в основном процессе (Pitfall 9) | Прямая работа Pigeon-моста | При подключении core нужна миграция на IPC | Для прототипа да; план миграции описать в README |
| `trafficChanged` из синтетического счётчика (если пакеты не читаются) | Живая статистика без TUN-чтения | Цифры не отражают реальность | Только если README честно называет источник данных |
| Пропуск обработки смерти процесса (`START_STICKY` рестарт без конфига) | Меньше кода | NPE при пересоздании сервиса системой | Для 48-часового прототипа приемлемо: `START_NOT_STICKY` + чистый teardown |
| iOS extension без запуска на устройстве | Экономия времени и не нужен платный аккаунт | Нет доказательства работоспособности | ТЗ явно допускает skeleton + доки |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| AndroidManifest / VpnService | Забыты `android:permission="android.permission.BIND_VPN_SERVICE"` или intent-filter `android.net.VpnService`; без permission любой app может биндиться к сервису, без intent-filter система не находит сервис | Оба атрибута обязательны; при targetSdk 31+ явно указать `android:exported` (сервис с intent-filter без exported не пройдёт сборку) |
| VpnService.Builder | `establish()` до `protect()` tunnel-сокета в будущем core: circular routing | Порядок из доков: prepare → protect → connect socket → Builder → establish; для прототипа отразить порядок в README-плане интеграции core |
| VpnService.Builder | Не задан `setSession()`/`addDnsServer`, забыт `setMtu` | Минимум: `setSession(name)`, `addAddress("10.x.x.x", 32)`, `addRoute(...)`, `addDnsServer(...)`, `setMtu(1500)` |
| Pigeon codegen | Генерация под Java/ObjC при использовании event channels | Только kotlinOut + swiftOut; версию pigeon зафиксировать |
| Flutter engine ↔ Service | Отправка событий до `onListen` подписчика | Native-кэш последнего статуса + replay в onListen + `getStatus()` при старте |
| iOS app ↔ extension | Обмен конфигом через обычные UserDefaults | App Group у обоих таргетов; providerConfiguration в NETunnelProviderProtocol |
| VLESS URI | `Uri.parse` без URL-decode параметров (`path=%2Fws`, `sni`, `pbk`), IPv6-хост в `[]`, пустой fragment | Декодировать query/fragment; тесты на IPv6, проценты, отсутствующие параметры; валидация UUID |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| `trafficChanged`/`logMessage` чаще нескольких раз в секунду через мост | Джанк UI, разросшийся лог-виджет | Троттлинг на native-стороне (раз в 1 сек для трафика), ring buffer логов в Dart (последние N строк) | Уже при демо, лог за минуту работы |
| Чтение TUN по одному пакету с аллокацией буфера на каждый read | GC-паузы, батарея | Один переиспользуемый ByteBuffer на поток чтения | При варианте «читать и дропать» из Pitfall 2 |
| Пересоздание Timer/Stream-подписок при каждом rebuild | Дублирующиеся тики, утечки подписок | Подписки в state/bloc с dispose, не в build() | Через несколько минут работы экрана |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Сервис без `android:permission="android.permission.BIND_VPN_SERVICE"` | Произвольное приложение биндится к VPN-сервису | Атрибут в манифесте, проверка в code review фазы Android |
| Логирование полного VLESS URI (содержит UUID-креды) в logMessage/README/видео | Утечка учётных данных в демо-репозиторий и видео | В логи выводить редактированный конфиг (маскировать UUID), тестовые ссылки с фейковым UUID |
| Хранение распарсенного конфига в plaintext SharedPreferences | Чтение конфига при компрометации устройства | Для прототипа: держать в памяти; в README отметить Keystore/Keychain как продакшн-путь |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Кнопки активны в переходных состояниях | Двойной Connect ломает состояние сервиса | Connect активна только в Disconnected/Error, Disconnect только в Connected; в Connecting/Disconnecting обе заблокированы (требование ТЗ) |
| Отказ в VPN-consent без фидбека | Пользователь не понимает, почему «не подключается» | Событие error + понятный текст «разрешение на VPN отклонено» в лог-блоке |
| Статус Error без пути выхода | Тупиковое состояние UI | Error разрешает повторный Connect; текст ошибки в лог-блоке |
| Два системных диалога подряд (уведомления + VPN) без контекста | Пользователь жмёт «нет» рефлекторно | Запрашивать последовательно: уведомления при первом Connect, затем VPN-диалог |

## "Looks Done But Isn't" Checklist

- [ ] **Consent-флоу:** работает первый Connect, но не проверен повторный после включения другого VPN-приложения — проверить revoke + повторный prepare().
- [ ] **Foreground-уведомление:** видно на API 32, но не проверено на API 33+ с запросом POST_NOTIFICATIONS — прогнать на эмуляторе API 34/35.
- [ ] **foregroundServiceType:** работает на старом эмуляторе, падает на API 34 — обязательный прогон на targetSdk-уровне.
- [ ] **События:** приходят при первом запуске, но не после hot restart / перезапуска приложения при живом VPN — проверить getStatus()-восстановление и replay.
- [ ] **onRevoke:** код написан, но не вызван ни разу — руками включить второй VPN поверх.
- [ ] **Disconnect:** статус меняется, но уведомление висит / fd не закрыт — проверить шторку и повторный цикл connect → disconnect → connect x3.
- [ ] **iOS skeleton:** файлы лежат, но таргет не компилируется — `xcodebuild build` таргета extension в CI/локально.
- [ ] **VLESS-парсер:** happy path проходит, но нет тестов на IPv6-хост, URL-encoded path, отсутствующий port, кривой UUID.
- [ ] **Таймер:** тикает, но не проверен через hot restart при активном VPN.

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Крэш @UiThread на событиях | LOW | Обернуть эмиттер в main-thread post; точка одна, если эмиттер централизован |
| MissingForegroundServiceTypeException на API 34 | LOW | Добавить тип + permission в манифест, перегрузку startForeground |
| Потерянный интернет на демо (0.0.0.0/0 без core) | LOW | Сменить маршрут на узкую подсеть, перезаписать видео |
| Сервис в отдельном процессе, мост молчит | MEDIUM | Убрать android:process, перепроверить синглтон статуса; если IPC уже написан, откатить |
| UI навсегда в Connecting (отказ consent не обработан) | LOW | Добавить ветку RESULT_CANCELED → Error; state machine уже есть |
| iOS extension ломает flutter run | MEDIUM | Убрать extension из embed/схемы сборки, оставить компиляцию отдельным таргетом |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| P12 Pigeon генераторы/threading | Фаза Pigeon bridge | Генерация проходит для Kotlin+Swift; событие из фонового потока не роняет app |
| P4 Race событий / восстановление статуса | Фаза Pigeon bridge (контракт getStatus) + Flutter UI | Hot restart при живом VPN показывает Connected |
| P1 Consent-флоу | Фаза Android VpnService | Cancel в диалоге → Error; повторный Connect после чужого VPN работает |
| P2 Маршрут без core | Фаза Android VpnService | В Connected интернет устройства жив (или поведение задокументировано) |
| P3 Main thread события | Фаза Pigeon bridge + Android VpnService | Revoke-сценарий не крэшит |
| P5 foregroundServiceType | Фаза Android VpnService | Запуск на API 34/35 эмуляторе без крэша |
| P6 POST_NOTIFICATIONS | Фаза Android VpnService | Уведомление видно в шторке на API 34 |
| P7 onRevoke | Фаза Android VpnService | Второй VPN поверх → статус Disconnected + лог в UI |
| P8 fd/потоки | Фаза Android VpnService | 3 цикла connect/disconnect подряд стабильны |
| P10 startForeground timing | Фаза Android VpnService | Старт на холодном эмуляторе без DidNotStartInTime |
| P13 Таймер | Фаза Flutter UI/state | Таймер переживает hot restart |
| P11 iOS NE ограничения | Фаза iOS skeleton | xcodebuild таргета extension зелёный; README-раздел полный |
| VLESS-грабли | Фаза VLESS-парсер | Юнит-тесты: IPv6, percent-encoding, невалидный UUID, дефолты |

## Sources

- [Android: Create a VPN service](https://developer.android.com/develop/connectivity/vpn) — манифест, prepare(), onRevoke() (не main thread), establish() null, protect(), foreground-требования — HIGH
- [Android: Foreground service types](https://developer.android.com/develop/background-work/services/fg-service-types) — systemExempted явно включает VPN-приложения; specialUse и его Play-ревью — HIGH
- [Flutter: Platform channels — Channels and platform threading](https://docs.flutter.dev/platform-integration/platform-channels) — main thread для вызовов в сторону Dart, TaskQueue, паттерны Handler/DispatchQueue — HIGH
- [pub.dev: pigeon 27.1.1](https://pub.dev/packages/pigeon) — event channels только Swift/Kotlin/Dart генераторы — HIGH
- [flutter/flutter#161291](https://github.com/flutter/flutter/issues/161291) — ограничения EventChannelApi при нескольких input-файлах — MEDIUM
- [flutter/flutter#34993](https://github.com/flutter/flutter/issues/34993) — крэш «@UiThread must be executed on the main thread» при событиях с фонового потока — MEDIUM
- [Apple: NEPacketTunnelProvider](https://developer.apple.com/documentation/networkextension/nepackettunnelprovider), [TN3120](https://developer.apple.com/documentation/technotes/tn3120-expected-use-cases-for-network-extension-packet-tunnel-providers) — entitlement packet-tunnel у app и extension — HIGH
- [Apple Developer Forums: Network Extension в симуляторе](https://developer.apple.com/forums/thread/690345) — NE не работает в симуляторе, только физическое устройство — MEDIUM
- [VpnService API reference](https://developer.android.com/reference/android/net/VpnService) — детали prepare/establish/protect — HIGH

---
*Pitfalls research for: Flutter + native VPN (Android VpnService, iOS Network Extension, Pigeon)*
*Researched: 2026-07-13*
