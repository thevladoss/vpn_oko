package com.example.vpn_oko.vpn

import com.example.vpn_oko.bridge.VpnStatusMessage

sealed interface VpnConnectionState {
    data object Disconnected : VpnConnectionState
    data object Connecting : VpnConnectionState
    data class Connected(val sinceEpochMs: Long) : VpnConnectionState
    data object Disconnecting : VpnConnectionState
    data class Error(val code: String) : VpnConnectionState
}

fun VpnConnectionState.toStatusMessage(): VpnStatusMessage =
    when (this) {
        VpnConnectionState.Disconnected -> VpnStatusMessage.DISCONNECTED
        VpnConnectionState.Connecting -> VpnStatusMessage.CONNECTING
        is VpnConnectionState.Connected -> VpnStatusMessage.CONNECTED
        VpnConnectionState.Disconnecting -> VpnStatusMessage.DISCONNECTING
        is VpnConnectionState.Error -> VpnStatusMessage.ERROR
    }

fun canTransition(from: VpnConnectionState, to: VpnConnectionState): Boolean {
    if (to is VpnConnectionState.Error) return true
    return when (from) {
        VpnConnectionState.Disconnected ->
            to is VpnConnectionState.Connecting
        VpnConnectionState.Connecting ->
            to is VpnConnectionState.Connected || to is VpnConnectionState.Disconnecting
        is VpnConnectionState.Connected ->
            to is VpnConnectionState.Disconnecting
        VpnConnectionState.Disconnecting ->
            to is VpnConnectionState.Disconnected
        is VpnConnectionState.Error ->
            to is VpnConnectionState.Connecting || to is VpnConnectionState.Disconnected
    }
}
