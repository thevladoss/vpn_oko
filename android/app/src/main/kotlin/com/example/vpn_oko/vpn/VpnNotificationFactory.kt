package com.example.vpn_oko.vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context

class VpnNotificationFactory(private val context: Context) {

    fun ensureChannel() {
        val channel = NotificationChannel(CHANNEL_ID, "VPN", NotificationManager.IMPORTANCE_LOW)
        context.getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    fun building(text: String): Notification =
        Notification.Builder(context, CHANNEL_ID)
            .setContentTitle("Oko VPN")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true)
            .build()

    companion object {
        const val CHANNEL_ID = "oko_vpn"
        const val NOTIFICATION_ID = 1001
    }
}
