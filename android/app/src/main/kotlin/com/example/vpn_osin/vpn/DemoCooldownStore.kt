package com.example.vpn_osin.vpn

import android.content.Context

interface LongStore {
    fun get(key: String): Long?
    fun set(key: String, value: Long)
}

class DemoCooldownStore(private val store: LongStore) {

    fun recordExpiry(now: Long) {
        store.set(KEY_LAST_EXPIRED, now)
    }

    fun cooldownUntil(now: Long): Long? {
        val lastExpiredAt = store.get(KEY_LAST_EXPIRED) ?: return null
        val until = lastExpiredAt + DemoLimit.COOLDOWN_MS
        return if (until > now) until else null
    }

    fun isInCooldown(now: Long): Boolean = cooldownUntil(now) != null

    companion object {
        private const val KEY_LAST_EXPIRED = "last_expired_at"

        fun from(context: Context): DemoCooldownStore =
            DemoCooldownStore(SharedPreferencesLongStore(context.applicationContext))
    }
}

class SharedPreferencesLongStore(context: Context) : LongStore {

    private val prefs = context.getSharedPreferences("oko_demo_limit", Context.MODE_PRIVATE)

    override fun get(key: String): Long? =
        if (prefs.contains(key)) prefs.getLong(key, 0L) else null

    override fun set(key: String, value: Long) {
        prefs.edit().putLong(key, value).apply()
    }
}
