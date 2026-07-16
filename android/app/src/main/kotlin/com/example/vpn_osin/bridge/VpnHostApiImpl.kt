package com.example.vpn_oko.bridge

import com.example.vpn_oko.vpn.DemoCooldownStore

class VpnHostApiImpl(
    private val gateway: VpnConsentGateway,
    private val store: DemoCooldownStore,
) : VpnHostApi {
    override fun startVpn(config: VpnConfigMessage, callback: (Result<Unit>) -> Unit) {
        gateway.connect(config)
        callback(Result.success(Unit))
    }

    override fun stopVpn(callback: (Result<Unit>) -> Unit) {
        gateway.disconnect()
        callback(Result.success(Unit))
    }

    override fun getStatus(): VpnStatusSnapshotMessage =
        VpnEventBus.snapshot.copy(cooldownUntilEpochMs = store.cooldownUntil(System.currentTimeMillis()))
}
