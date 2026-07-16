package com.example.vpn_osin.bridge

import android.os.Handler
import android.os.Looper

class VpnEventListener : VpnEventsStreamHandler() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var sink: PigeonEventSink<VpnEventMessage>? = null
    private val forward: (VpnEventMessage) -> Unit = { event ->
        mainHandler.post { sink?.success(event) }
    }

    override fun onListen(p0: Any?, sink: PigeonEventSink<VpnEventMessage>) {
        this.sink = sink
        VpnEventBus.addListener(forward)
    }

    override fun onCancel(p0: Any?) {
        VpnEventBus.removeListener(forward)
        sink = null
    }
}
