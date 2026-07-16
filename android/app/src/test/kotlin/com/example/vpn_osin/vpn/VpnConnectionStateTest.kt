package com.example.vpn_osin.vpn

import com.example.vpn_osin.bridge.VpnStatusMessage
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class VpnConnectionStateTest {

    @Test
    fun mapsEveryStateToStatusMessage() {
        assertEquals(VpnStatusMessage.DISCONNECTED, VpnConnectionState.Disconnected.toStatusMessage())
        assertEquals(VpnStatusMessage.CONNECTING, VpnConnectionState.Connecting.toStatusMessage())
        assertEquals(VpnStatusMessage.CONNECTED, VpnConnectionState.Connected(1L).toStatusMessage())
        assertEquals(VpnStatusMessage.DISCONNECTING, VpnConnectionState.Disconnecting.toStatusMessage())
        assertEquals(VpnStatusMessage.ERROR, VpnConnectionState.Error("boom").toStatusMessage())
    }

    @Test
    fun allowsValidTransitions() {
        assertTrue(canTransition(VpnConnectionState.Disconnected, VpnConnectionState.Connecting))
        assertTrue(canTransition(VpnConnectionState.Connecting, VpnConnectionState.Connected(1L)))
        assertTrue(canTransition(VpnConnectionState.Connecting, VpnConnectionState.Disconnecting))
        assertTrue(canTransition(VpnConnectionState.Connecting, VpnConnectionState.Error("e")))
        assertTrue(canTransition(VpnConnectionState.Connected(1L), VpnConnectionState.Disconnecting))
        assertTrue(canTransition(VpnConnectionState.Connected(1L), VpnConnectionState.Error("e")))
        assertTrue(canTransition(VpnConnectionState.Disconnecting, VpnConnectionState.Disconnected))
        assertTrue(canTransition(VpnConnectionState.Disconnecting, VpnConnectionState.Error("e")))
        assertTrue(canTransition(VpnConnectionState.Error("e"), VpnConnectionState.Connecting))
        assertTrue(canTransition(VpnConnectionState.Error("e"), VpnConnectionState.Disconnected))
    }

    @Test
    fun allowsTransitionToErrorFromAnyState() {
        assertTrue(canTransition(VpnConnectionState.Disconnected, VpnConnectionState.Error("e")))
        assertTrue(canTransition(VpnConnectionState.Connecting, VpnConnectionState.Error("e")))
        assertTrue(canTransition(VpnConnectionState.Connected(1L), VpnConnectionState.Error("e")))
        assertTrue(canTransition(VpnConnectionState.Disconnecting, VpnConnectionState.Error("e")))
        assertTrue(canTransition(VpnConnectionState.Error("a"), VpnConnectionState.Error("b")))
    }

    @Test
    fun rejectsInvalidTransitions() {
        assertFalse(canTransition(VpnConnectionState.Disconnected, VpnConnectionState.Connected(1L)))
        assertFalse(canTransition(VpnConnectionState.Disconnected, VpnConnectionState.Disconnecting))
        assertFalse(canTransition(VpnConnectionState.Connected(1L), VpnConnectionState.Connecting))
    }
}
