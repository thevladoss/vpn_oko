package com.example.vpn_osin

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import com.example.vpn_osin.bridge.DemoExpiredMessage
import com.example.vpn_osin.bridge.ErrorMessage
import com.example.vpn_osin.bridge.LogMessage
import com.example.vpn_osin.bridge.StatusChangedMessage
import com.example.vpn_osin.bridge.VpnConfigMessage
import com.example.vpn_osin.bridge.VpnConsentGateway
import com.example.vpn_osin.bridge.VpnEventBus
import com.example.vpn_osin.bridge.VpnEventListener
import com.example.vpn_osin.bridge.VpnEventsStreamHandler
import com.example.vpn_osin.bridge.VpnHostApi
import com.example.vpn_osin.bridge.VpnHostApiImpl
import com.example.vpn_osin.bridge.VpnStatusMessage
import com.example.vpn_osin.vpn.DemoCooldownStore
import com.example.vpn_osin.vpn.OsinVpnService
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity(), VpnConsentGateway {

    private var pendingConfig: VpnConfigMessage? = null
    private lateinit var demoStore: DemoCooldownStore

    private val vpnConsent =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
            val config = pendingConfig
            pendingConfig = null
            if (result.resultCode == RESULT_OK && config != null) {
                startVpnService(config)
            } else {
                VpnEventBus.emit(
                    LogMessage("VPN permission denied", System.currentTimeMillis(), "error"),
                )
                VpnEventBus.emit(ErrorMessage("consent_denied", "VPN permission denied by user"))
                VpnEventBus.emit(StatusChangedMessage(VpnStatusMessage.ERROR))
            }
        }

    private val notifPermission =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
            if (!granted) {
                VpnEventBus.emit(
                    LogMessage("notifications denied", System.currentTimeMillis(), "warning"),
                )
            }
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        demoStore = DemoCooldownStore.from(this)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        VpnHostApi.setUp(messenger, VpnHostApiImpl(this, demoStore))
        VpnEventsStreamHandler.register(messenger, VpnEventListener())
    }

    override fun connect(config: VpnConfigMessage) {
        val now = System.currentTimeMillis()
        val until = demoStore.cooldownUntil(now)
        if (until != null) {
            VpnEventBus.emit(LogMessage("connect blocked: cooldown", now, "warning"))
            VpnEventBus.emit(DemoExpiredMessage(until))
            return
        }
        ensureNotificationPermission()
        val consent = VpnService.prepare(this)
        if (consent == null) {
            startVpnService(config)
        } else {
            pendingConfig = config
            vpnConsent.launch(consent)
        }
    }

    override fun disconnect() {
        startService(
            Intent(this, OsinVpnService::class.java).setAction(OsinVpnService.ACTION_DISCONNECT),
        )
    }

    private fun ensureNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            notifPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
    }

    private fun startVpnService(config: VpnConfigMessage) {
        val intent = Intent(this, OsinVpnService::class.java)
            .setAction(OsinVpnService.ACTION_CONNECT)
            .putExtra(OsinVpnService.EXTRA_HOST, config.host)
            .putExtra(OsinVpnService.EXTRA_PORT, config.port)
            .putExtra(OsinVpnService.EXTRA_USER_ID, config.userId)
            .putExtra(OsinVpnService.EXTRA_SERVER_NAME, config.serverName)
            .putExtra(OsinVpnService.EXTRA_CONFIG_JSON, config.singboxConfigJson)
        startForegroundService(intent)
    }
}
