package com.example.vpn_osin.bridge

interface VpnConsentGateway {
    fun connect(config: VpnConfigMessage)
    fun disconnect()
}
