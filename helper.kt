package com.vamsi.livenotifications.utils

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.vamsi.livenotifications.MainActivity
import com.vamsi.livenotifications.R
import com.vamsi.livenotifications.model.DeliveryStatus
import java.text.SimpleDateFormat
import java.util.*

class NotificationHelper(private val context: Context) {

    companion object {
        const val CHANNEL_ID = "delivery_updates"
        const val NOTIFICATION_ID = 1001
        private const val CHANNEL_NAME = "Delivery Updates"
        private const val CHANNEL_DESCRIPTION = "Real-time delivery progress notifications"
    }

    private val notificationManager =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private val liveUpdatesBuilder = LiveUpdatesNotificationBuilder(context)

    init {
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = CHANNEL_DESCRIPTION
            enableLights(true)
            lightColor = Color.BLUE
            enableVibration(true)
            setShowBadge(true)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        notificationManager.createNotificationChannel(channel)
    }

    fun createProgressNotification(status: DeliveryStatus): Notification {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }

        val pendingIntent = PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val progressPercentage = status.getProgressPercentage()
        val maxProgress = 100
        val statusColor = ContextCompat.getColor(context, status.colorRes)

        val etaText = if (status.estimatedMinutes > 0) {
            "ETA: ${formatETA(status.estimatedMinutes)}"
        } else {
            "Completed!"
        }

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(status.iconRes)
            .setContentTitle(status.displayName)
            .setContentText(status.description)
            .setSubText(etaText)
            .setContentIntent(pendingIntent)
            .setAutoCancel(false)
            .setOngoing(status != DeliveryStatus.DELIVERED)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setColor(statusColor)
            .setProgress(maxProgress, progressPercentage, false)

        // Add progress-centric notification features for Android 16+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            // This would be where we'd add ProgressStyle features when available
            // For now, we'll use enhanced progress indicators
            builder.setStyle(
                NotificationCompat.BigTextStyle()
                    .bigText("${status.description}\n\n$etaText\nProgress: ${progressPercentage}%")
                    .setBigContentTitle(status.displayName)
            )
        }

        // Add action buttons
        if (status != DeliveryStatus.DELIVERED) {
            val trackIntent = Intent(context, MainActivity::class.java)
            val trackPendingIntent = PendingIntent.getActivity(
                context, 1, trackIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            builder.addAction(
                R.drawable.ic_view,
                "Track Order",
                trackPendingIntent
            )
        }

        return builder.build()
    }

    fun createLiveUpdateNotification(
        status: DeliveryStatus,
        currentProgress: Int = 0,
    ): Notification {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.BAKLAVA) {
            // Use official Android 16 Live Updates API
            liveUpdatesBuilder.buildLiveUpdateNotification(
                status = status,
                channelId = CHANNEL_ID,
                currentProgress = currentProgress
            )
        } else {
            // Fallback for older Android versions
            liveUpdatesBuilder.buildFallbackNotification(
                status = status,
                channelId = CHANNEL_ID,
                currentProgress = currentProgress
            )
        }
    }

    // Legacy method for backward compatibility
    @Deprecated("Use createLiveUpdateNotification instead")
    fun createProgressStyleNotification(
        status: DeliveryStatus,
    ): Notification {
        return createLiveUpdateNotification(status, status.getCumulativeProgress())
    }

    private fun formatETA(minutes: Int): String {
        val calendar = Calendar.getInstance()
        calendar.add(Calendar.MINUTE, minutes)
        val formatter = SimpleDateFormat("h:mm a", Locale.getDefault())
        return formatter.format(calendar.time)
    }

    fun showNotification(notification: Notification) {
        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    fun cancelNotification() {
        notificationManager.cancel(NOTIFICATION_ID)
    }
}