package com.example.vpn_oko.bridge

interface VpnConsentGateway {
    fun connect(config: VpnConfigMessage)
    fun disconnect()
}
