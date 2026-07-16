package com.example.vpn_osin.bridge

import com.example.vpn_osin.vpn.DemoLimit

object VpnEventBus {
    private val listeners =
        java.util.concurrent.CopyOnWriteArraySet<(VpnEventMessage) -> Unit>()

    @Volatile
    var lastStatus: StatusChangedMessage =
        StatusChangedMessage(status = VpnStatusMessage.DISCONNECTED)
        private set

    @Volatile
    var snapshot: VpnStatusSnapshotMessage =
        VpnStatusSnapshotMessage(
            status = VpnStatusMessage.DISCONNECTED,
            rxBytes = 0L,
            txBytes = 0L,
        )
        private set

    @Synchronized
    fun addListener(listener: (VpnEventMessage) -> Unit) {
        listeners += listener
        listener(lastStatus)
    }

    fun removeListener(listener: (VpnEventMessage) -> Unit) {
        listeners -= listener
    }

    @Synchronized
    fun emit(event: VpnEventMessage) {
        when (event) {
            is StatusChangedMessage -> {
                lastStatus = event
                val sessionEndsAt =
                    if (event.status == VpnStatusMessage.CONNECTED && event.connectedSinceEpochMs != null) {
                        event.connectedSinceEpochMs + DemoLimit.SESSION_MS
                    } else {
                        null
                    }
                snapshot = snapshot.copy(
                    status = event.status,
                    connectedSinceEpochMs = event.connectedSinceEpochMs,
                    sessionEndsAtEpochMs = sessionEndsAt,
                )
            }
            is TrafficChangedMessage -> {
                snapshot = snapshot.copy(
                    rxBytes = event.rxBytes,
                    txBytes = event.txBytes,
                )
            }
            else -> {}
        }
        listeners.toList().forEach { it(event) }
    }
}
