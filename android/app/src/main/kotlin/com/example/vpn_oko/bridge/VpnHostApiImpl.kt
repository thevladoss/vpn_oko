package com.example.vpn_oko.bridge

class VpnHostApiImpl(private val gateway: VpnConsentGateway) : VpnHostApi {
    override fun startVpn(config: VpnConfigMessage, callback: (Result<Unit>) -> Unit) {
        gateway.connect(config)
        callback(Result.success(Unit))
    }

    override fun stopVpn(callback: (Result<Unit>) -> Unit) {
        gateway.disconnect()
        callback(Result.success(Unit))
    }

    override fun getStatus(): VpnStatusSnapshotMessage = VpnEventBus.snapshot
}
