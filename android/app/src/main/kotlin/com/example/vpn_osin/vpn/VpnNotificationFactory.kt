package com.example.vpn_osin.vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import com.example.vpn_osin.MainActivity

class VpnNotificationFactory(private val context: Context) {

    fun ensureChannel() {
        val channel = NotificationChannel(CHANNEL_ID, "VPN", NotificationManager.IMPORTANCE_LOW)
        context.getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    fun building(text: String, connectedSinceMs: Long? = null): Notification =
        Notification.Builder(context, CHANNEL_ID)
            .setContentTitle("osin VPN")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true)
            .setContentIntent(openAppIntent())
            .apply {
                if (connectedSinceMs != null) {
                    setWhen(connectedSinceMs)
                    setShowWhen(true)
                    setUsesChronometer(true)
                }
            }
            .build()

    private fun openAppIntent(): PendingIntent {
        val launch = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context,
            0,
            launch,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    companion object {
        const val CHANNEL_ID = "osin_vpn"
        const val NOTIFICATION_ID = 1001
    }
}
