package com.example.vpn_oko

import com.example.vpn_oko.bridge.VpnEventListener
import com.example.vpn_oko.bridge.VpnEventsStreamHandler
import com.example.vpn_oko.bridge.VpnHostApi
import com.example.vpn_oko.bridge.VpnHostApiImpl
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        VpnHostApi.setUp(messenger, VpnHostApiImpl())
        VpnEventsStreamHandler.register(messenger, VpnEventListener())
    }
}
