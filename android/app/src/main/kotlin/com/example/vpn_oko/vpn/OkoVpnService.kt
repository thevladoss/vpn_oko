package com.example.vpn_oko.vpn

import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.ParcelFileDescriptor
import androidx.core.app.ServiceCompat
import com.example.vpn_oko.bridge.ErrorMessage
import com.example.vpn_oko.bridge.LogMessage
import com.example.vpn_oko.bridge.StatusChangedMessage
import com.example.vpn_oko.bridge.VpnEventBus

class OkoVpnService : VpnService() {

    private var state: VpnConnectionState = VpnConnectionState.Disconnected
    private var tunnel: ParcelFileDescriptor? = null
    private val notificationFactory by lazy { VpnNotificationFactory(this) }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_DISCONNECT) {
            teardown("stopped by user")
            return START_NOT_STICKY
        }
        if (intent == null) {
            stopSelf()
            return START_NOT_STICKY
        }

        notificationFactory.ensureChannel()
        ServiceCompat.startForeground(
            this,
            VpnNotificationFactory.NOTIFICATION_ID,
            notificationFactory.building("Connecting…"),
            ServiceInfo.FOREGROUND_SERVICE_TYPE_SYSTEM_EXEMPTED,
        )

        transition(VpnConnectionState.Connecting)

        val host = intent.getStringExtra(EXTRA_HOST).orEmpty()
        val port = intent.getLongExtra(EXTRA_PORT, 0L)
        val serverName = intent.getStringExtra(EXTRA_SERVER_NAME).orEmpty()
        if (host.isBlank() || port !in 1L..65535L) {
            failStart("invalid_config", "invalid host or port")
            return START_NOT_STICKY
        }

        val descriptor = buildTunnel(serverName)
        if (descriptor == null) {
            failStart("establish_failed", "establish returned null")
            return START_NOT_STICKY
        }

        tunnel = descriptor
        transition(VpnConnectionState.Connected(System.currentTimeMillis()))
        return START_NOT_STICKY
    }

    private fun buildTunnel(serverName: String): ParcelFileDescriptor? =
        Builder()
            .setSession(if (serverName.isBlank()) "Oko VPN" else serverName)
            .addAddress("10.0.0.2", 32)
            .addRoute("10.111.222.0", 24)
            .addDnsServer("1.1.1.1")
            .setMtu(1500)
            .establish()

    private fun failStart(code: String, reason: String) {
        VpnEventBus.emit(LogMessage(reason, System.currentTimeMillis(), "error"))
        VpnEventBus.emit(ErrorMessage(code, reason))
        transition(VpnConnectionState.Error(code))
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun transition(next: VpnConnectionState) {
        if (!canTransition(state, next)) {
            VpnEventBus.emit(
                LogMessage("illegal transition $state -> $next", System.currentTimeMillis(), "error"),
            )
            return
        }
        state = next
        val status = next.toStatusMessage()
        VpnEventBus.emit(LogMessage("state -> $status", System.currentTimeMillis(), "info"))
        VpnEventBus.emit(
            StatusChangedMessage(status, (next as? VpnConnectionState.Connected)?.sinceEpochMs),
        )
    }

    @Synchronized
    private fun teardown(reason: String) {
        if (state is VpnConnectionState.Disconnected) return
        transition(VpnConnectionState.Disconnecting)
        tunnel?.close()
        tunnel = null
        VpnEventBus.emit(LogMessage(reason, System.currentTimeMillis(), "info"))
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        transition(VpnConnectionState.Disconnected)
        stopSelf()
    }

    override fun onDestroy() {
        tunnel?.close()
        tunnel = null
        super.onDestroy()
    }

    companion object {
        const val ACTION_CONNECT = "com.example.vpn_oko.action.CONNECT"
        const val ACTION_DISCONNECT = "com.example.vpn_oko.action.DISCONNECT"
        const val EXTRA_HOST = "com.example.vpn_oko.extra.HOST"
        const val EXTRA_PORT = "com.example.vpn_oko.extra.PORT"
        const val EXTRA_USER_ID = "com.example.vpn_oko.extra.USER_ID"
        const val EXTRA_SERVER_NAME = "com.example.vpn_oko.extra.SERVER_NAME"
    }
}
