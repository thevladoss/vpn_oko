package com.example.vpn_oko.bridge

class VpnHostApiImpl : VpnHostApi {
    override fun startVpn(config: VpnConfigMessage, callback: (Result<Unit>) -> Unit) {
        VpnEventBus.emit(
            LogMessage(
                text = "starting",
                timestampMillis = System.currentTimeMillis(),
                level = "info",
            ),
        )
        VpnEventBus.emit(StatusChangedMessage(status = VpnStatusMessage.CONNECTING))
        VpnEventBus.emit(
            LogMessage(
                text = "tunnel up",
                timestampMillis = System.currentTimeMillis(),
                level = "info",
            ),
        )
        VpnEventBus.emit(
            StatusChangedMessage(
                status = VpnStatusMessage.CONNECTED,
                connectedSinceEpochMs = System.currentTimeMillis(),
            ),
        )
        callback(Result.success(Unit))
    }

    override fun stopVpn(callback: (Result<Unit>) -> Unit) {
        VpnEventBus.emit(StatusChangedMessage(status = VpnStatusMessage.DISCONNECTING))
        VpnEventBus.emit(StatusChangedMessage(status = VpnStatusMessage.DISCONNECTED))
        callback(Result.success(Unit))
    }

    override fun getStatus(): VpnStatusSnapshotMessage = VpnEventBus.snapshot
}
