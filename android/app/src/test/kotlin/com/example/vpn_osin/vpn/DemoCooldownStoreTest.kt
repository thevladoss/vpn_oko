package com.example.vpn_osin.vpn

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class DemoCooldownStoreTest {

    private class FakeLongStore : LongStore {
        private val values = mutableMapOf<String, Long>()

        override fun get(key: String): Long? = values[key]

        override fun set(key: String, value: Long) {
            values[key] = value
        }
    }

    private fun store() = DemoCooldownStore(FakeLongStore())

    @Test
    fun freshStoreHasNoCooldown() {
        val demo = store()
        assertNull(demo.cooldownUntil(1_000_000L))
        assertFalse(demo.isInCooldown(1_000_000L))
    }

    @Test
    fun recordExpiryOpensCooldownWindow() {
        val demo = store()
        demo.recordExpiry(1_000_000L)
        assertEquals(1_000_000L + DemoLimit.COOLDOWN_MS, demo.cooldownUntil(1_000_000L))
        assertTrue(demo.isInCooldown(1_000_000L))
    }

    @Test
    fun cooldownInactiveExactlyAtBoundary() {
        val demo = store()
        demo.recordExpiry(1_000_000L)
        val boundary = 1_000_000L + DemoLimit.COOLDOWN_MS
        assertFalse(demo.isInCooldown(boundary))
        assertNull(demo.cooldownUntil(boundary))
    }

    @Test
    fun cooldownActiveOneMillisBeforeBoundary() {
        val demo = store()
        demo.recordExpiry(1_000_000L)
        val justBefore = 1_000_000L + DemoLimit.COOLDOWN_MS - 1
        assertTrue(demo.isInCooldown(justBefore))
        assertEquals(1_000_000L + DemoLimit.COOLDOWN_MS, demo.cooldownUntil(justBefore))
    }

    @Test
    fun expiredCooldownReturnsNull() {
        val demo = store()
        demo.recordExpiry(1_000_000L)
        assertNull(demo.cooldownUntil(2_000_000L))
        assertFalse(demo.isInCooldown(2_000_000L))
    }

    @Test
    fun secondExpiryMovesWindow() {
        val demo = store()
        demo.recordExpiry(1_000_000L)
        demo.recordExpiry(1_500_000L)
        assertEquals(1_500_000L + DemoLimit.COOLDOWN_MS, demo.cooldownUntil(1_500_000L))
        assertEquals(
            1_500_000L + DemoLimit.COOLDOWN_MS,
            demo.cooldownUntil(1_000_000L + DemoLimit.COOLDOWN_MS),
        )
    }
}
