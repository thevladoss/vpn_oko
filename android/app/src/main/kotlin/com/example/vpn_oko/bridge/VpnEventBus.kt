package com.example.vpn_oko.bridge

object VpnEventBus {
    private val listeners = mutableSetOf<(VpnEventMessage) -> Unit>()

    var lastStatus: StatusChangedMessage =
        StatusChangedMessage(status = VpnStatusMessage.DISCONNECTED)
        private set

    var snapshot: VpnStatusSnapshotMessage =
        VpnStatusSnapshotMessage(
            status = VpnStatusMessage.DISCONNECTED,
            rxBytes = 0L,
            txBytes = 0L,
        )
        private set

    fun addListener(listener: (VpnEventMessage) -> Unit) {
        listeners += listener
        listener(lastStatus)
    }

    fun removeListener(listener: (VpnEventMessage) -> Unit) {
        listeners -= listener
    }

    fun emit(event: VpnEventMessage) {
        if (event is StatusChangedMessage) {
            lastStatus = event
            snapshot = VpnStatusSnapshotMessage(
                status = event.status,
                connectedSinceEpochMs = event.connectedSinceEpochMs,
                rxBytes = snapshot.rxBytes,
                txBytes = snapshot.txBytes,
            )
        }
        listeners.toList().forEach { it(event) }
    }
}
