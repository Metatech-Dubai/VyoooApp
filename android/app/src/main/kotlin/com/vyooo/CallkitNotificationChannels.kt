package com.vyooo

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.graphics.Color
import android.os.Build

/**
 * Ensures flutter_callkit_incoming notification channels exist before the first
 * accept. Full-screen incoming UI skips [showIncomingNotification], so channels
 * are otherwise only created on accept — too late for Android 14+ FGS rules.
 */
object CallkitNotificationChannels {
    const val INCOMING = "callkit_incoming_channel_id_v2"
    const val MISSED = "callkit_missed_channel_id"
    const val ONGOING = "callkit_ongoing_channel_id"

    fun ensureCreated(notificationManager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val incoming = NotificationChannel(
            INCOMING,
            "Vyooo Incoming Calls",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Incoming call alerts"
            vibrationPattern = longArrayOf(0, 1000, 500, 1000, 500)
            enableLights(true)
            lightColor = Color.RED
            enableVibration(true)
            setSound(null, null)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        notificationManager.createNotificationChannel(incoming)

        val missed = NotificationChannel(
            MISSED,
            "Vyooo Missed Calls",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Missed call alerts"
            vibrationPattern = longArrayOf(0, 1000)
            enableLights(true)
            lightColor = Color.RED
            enableVibration(true)
        }
        notificationManager.createNotificationChannel(missed)

        val existingOngoing = notificationManager.getNotificationChannel(ONGOING)
        if (existingOngoing != null &&
            existingOngoing.importance < NotificationManager.IMPORTANCE_DEFAULT
        ) {
            notificationManager.deleteNotificationChannel(ONGOING)
        }
        if (notificationManager.getNotificationChannel(ONGOING) == null) {
            val ongoing = NotificationChannel(
                ONGOING,
                "Vyooo Active Calls",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "Ongoing call status"
                setSound(null, null)
            }
            notificationManager.createNotificationChannel(ongoing)
        }
    }
}
