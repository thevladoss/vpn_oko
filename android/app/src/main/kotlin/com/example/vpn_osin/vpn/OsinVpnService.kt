package com.example.vpn_osin.vpn

import android.app.NotificationManager
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import androidx.core.app.ServiceCompat
import com.example.vpn_osin.bridge.DemoExpiredMessage
import com.example.vpn_osin.bridge.ErrorMessage
import com.example.vpn_osin.bridge.StatusChangedMessage
import com.example.vpn_osin.bridge.TrafficChangedMessage
import com.example.vpn_osin.bridge.VpnEventBus
import io.nekohasekai.libbox.CommandClient
import io.nekohasekai.libbox.CommandClientHandler
import io.nekohasekai.libbox.CommandClientOptions
import io.nekohasekai.libbox.CommandServer
import io.nekohasekai.libbox.CommandServerHandler
import io.nekohasekai.libbox.ConnectionEvents
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.LogIterator
import io.nekohasekai.libbox.OutboundGroupIterator
import io.nekohasekai.libbox.OverrideOptions
import io.nekohasekai.libbox.SetupOptions
import io.nekohasekai.libbox.StatusMessage
import io.nekohasekai.libbox.StringIterator
import io.nekohasekai.libbox.SystemProxyStatus
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

class OsinVpnService : VpnService(), CommandServerHandler {

    private var state: VpnConnectionState = VpnConnectionState.Disconnected
    private val notificationFactory by lazy { VpnNotificationFactory(this) }
    private val demoStore by lazy { DemoCooldownStore.from(this) }
    private val mainHandler = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "osin-vpn-core").also { it.isDaemon = true }
    }

    @Volatile
    private var demoTimer: ScheduledExecutorService? = null

    @Volatile
    private var expiredByDemo = false

    @Volatile
    private var tunnel: ParcelFileDescriptor? = null

    @Volatile
    private var commandServer: CommandServer? = null

    @Volatile
    private var trafficClient: CommandClient? = null

    @Volatile
    private var platform: OsinPlatformInterface? = null

    override fun onCreate() {
        super.onCreate()
        ensureLibboxSetup()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_DISCONNECT) {
            teardown("stopped by user")
            return START_NOT_STICKY
        }
        if (intent == null) {
            stopSelf()
            return START_NOT_STICKY
        }

        expiredByDemo = false
        notificationFactory.ensureChannel()
        ServiceCompat.startForeground(
            this,
            VpnNotificationFactory.NOTIFICATION_ID,
            notificationFactory.building("Connecting…"),
            ServiceInfo.FOREGROUND_SERVICE_TYPE_SYSTEM_EXEMPTED,
        )

        if (!transition(VpnConnectionState.Connecting)) {
            return START_NOT_STICKY
        }

        val configJson = intent.getStringExtra(EXTRA_CONFIG_JSON).orEmpty()
        if (configJson.isBlank()) {
            failStart("invalid_config", "empty singbox config")
            return START_NOT_STICKY
        }

        worker.execute { startCore(configJson) }
        return START_NOT_STICKY
    }

    private fun startCore(configJson: String) {
        try {
            Libbox.checkConfig(configJson)
        } catch (error: Exception) {
            failStart("invalid_config", error.message ?: "config rejected by core")
            return
        }

        try {
            val platformInterface = OsinPlatformInterface(this) { Builder() }
            platform = platformInterface
            val server = Libbox.newCommandServer(this, platformInterface)
            server.start()
            commandServer = server
            server.startOrReloadService(configJson, OverrideOptions())
        } catch (error: Exception) {
            failStart("core_start_failed", error.message ?: "core failed to start")
            return
        }

        startTrafficClient()
        val connectedSince = System.currentTimeMillis()
        transition(VpnConnectionState.Connected(connectedSince))
        updateNotification("Connected", connectedSince)
        scheduleExpiry()
    }

    private fun scheduleExpiry() {
        cancelDemoTimer()
        val timer = Executors.newSingleThreadScheduledExecutor { runnable ->
            Thread(runnable, "osin-demo-timer").also { it.isDaemon = true }
        }
        timer.schedule({ expireSession() }, DemoLimit.SESSION_MS, TimeUnit.MILLISECONDS)
        demoTimer = timer
    }

    private fun expireSession() {
        val now = System.currentTimeMillis()
        demoStore.recordExpiry(now)
        val cooldownUntil = demoStore.cooldownUntil(now) ?: (now + DemoLimit.COOLDOWN_MS)
        mainHandler.post {
            expiredByDemo = true
            VpnEventBus.emit(DemoExpiredMessage(cooldownUntil))
            teardown("session ended by demo limit")
        }
    }

    private fun cancelDemoTimer() {
        demoTimer?.shutdownNow()
        demoTimer = null
    }

    private fun startTrafficClient() {
        runCatching {
            val options = CommandClientOptions().apply {
                addCommand(Libbox.CommandStatus)
                statusInterval = STATUS_INTERVAL_NANOS
            }
            val client = CommandClient(TrafficHandler(), options)
            client.connect()
            trafficClient = client
        }
    }

    private fun ensureLibboxSetup() {
        if (libboxSetup.getAndSet(true)) return
        runCatching {
            val working = File(filesDir, "singbox").also { it.mkdirs() }
            Libbox.setup(
                SetupOptions().apply {
                    basePath = filesDir.absolutePath
                    workingPath = working.absolutePath
                    tempPath = cacheDir.absolutePath
                    fixAndroidStack = true
                    logMaxLines = LOG_MAX_LINES
                    debug = false
                },
            )
        }.onFailure {
            libboxSetup.set(false)
        }
    }

    private fun updateNotification(text: String, connectedSinceMs: Long? = null) {
        getSystemService(NotificationManager::class.java)
            .notify(VpnNotificationFactory.NOTIFICATION_ID, notificationFactory.building(text, connectedSinceMs))
    }

    internal fun attachTunnel(descriptor: ParcelFileDescriptor) {
        tunnel = descriptor
    }

    override fun serviceStop() {
        teardown("core requested stop")
    }

    override fun serviceReload() {
    }

    override fun getSystemProxyStatus(): SystemProxyStatus =
        SystemProxyStatus().apply {
            available = false
            enabled = false
        }

    override fun setSystemProxyEnabled(isEnabled: Boolean) {
    }

    override fun writeDebugMessage(message: String?) {}

    private fun failStart(code: String, reason: String) {
        VpnEventBus.emit(ErrorMessage(code, reason))
        releaseCore()
        transition(VpnConnectionState.Error(code))
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    @Synchronized
    private fun transition(next: VpnConnectionState): Boolean {
        if (!canTransition(state, next)) {
            return false
        }
        state = next
        val status = next.toStatusMessage()
        VpnEventBus.emit(
            StatusChangedMessage(status, (next as? VpnConnectionState.Connected)?.sinceEpochMs),
        )
        return true
    }

    @Synchronized
    private fun teardown(reason: String) {
        if (state !is VpnConnectionState.Connecting && state !is VpnConnectionState.Connected) return
        cancelDemoTimer()
        transition(VpnConnectionState.Disconnecting)
        releaseCore()
        if (expiredByDemo) {
            updateExpiredNotification()
            ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_DETACH)
        } else {
            ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        }
        transition(VpnConnectionState.Disconnected)
        stopSelf()
    }

    private fun updateExpiredNotification() {
        getSystemService(NotificationManager::class.java).notify(
            VpnNotificationFactory.NOTIFICATION_ID,
            notificationFactory.expired("Демо: 5 минут вышло. Кулдаун 2 мин"),
        )
    }

    private fun releaseCore() {
        val client = trafficClient
        val server = commandServer
        val descriptor = tunnel
        trafficClient = null
        commandServer = null
        tunnel = null
        platform = null
        worker.execute {
            runCatching { client?.disconnect() }
            runCatching { server?.closeService() }
            runCatching { server?.close() }
            runCatching { descriptor?.close() }
        }
    }

    override fun onRevoke() {
        teardown("revoked by system")
    }

    override fun onDestroy() {
        teardown("service destroyed")
        cancelDemoTimer()
        worker.shutdown()
        super.onDestroy()
    }

    private inner class TrafficHandler : CommandClientHandler {
        override fun connected() {
        }

        override fun disconnected(message: String?) {
        }

        override fun clearLogs() {
        }

        override fun writeLogs(messageList: LogIterator?) {
        }

        override fun writeStatus(message: StatusMessage) {
            VpnEventBus.emit(TrafficChangedMessage(message.downlinkTotal, message.uplinkTotal))
        }

        override fun writeGroups(message: OutboundGroupIterator?) {
        }

        override fun initializeClashMode(modeList: StringIterator?, currentMode: String?) {
        }

        override fun updateClashMode(newMode: String?) {
        }

        override fun setDefaultLogLevel(level: Int) {
        }

        override fun writeConnectionEvents(message: ConnectionEvents?) {
        }
    }

    companion object {
        const val ACTION_CONNECT = "com.example.vpn_osin.action.CONNECT"
        const val ACTION_DISCONNECT = "com.example.vpn_osin.action.DISCONNECT"
        const val EXTRA_HOST = "com.example.vpn_osin.extra.HOST"
        const val EXTRA_PORT = "com.example.vpn_osin.extra.PORT"
        const val EXTRA_USER_ID = "com.example.vpn_osin.extra.USER_ID"
        const val EXTRA_SERVER_NAME = "com.example.vpn_osin.extra.SERVER_NAME"
        const val EXTRA_CONFIG_JSON = "com.example.vpn_osin.extra.CONFIG_JSON"

        private const val STATUS_INTERVAL_NANOS = 1_000_000_000L
        private const val LOG_MAX_LINES = 3000L
        private val libboxSetup = AtomicBoolean(false)
    }
}
