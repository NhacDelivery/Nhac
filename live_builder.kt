package com.vamsi.livenotifications.utils

import android.app.Notification
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.Icon
import android.os.Build
import androidx.annotation.RequiresApi
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.vamsi.livenotifications.MainActivity
import com.vamsi.livenotifications.R
import com.vamsi.livenotifications.model.DeliveryStatus
import java.text.SimpleDateFormat
import java.util.*

/**
 * Builder for Android 16 Live Updates using Notification.ProgressStyle
 * Following official Android documentation and guidelines
 */
class LiveUpdatesNotificationBuilder(private val context: Context) {

    @RequiresApi(Build.VERSION_CODES.BAKLAVA)
    fun buildLiveUpdateNotification(
        status: DeliveryStatus,
        channelId: String,
        currentProgress: Int = 0,
    ): Notification {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }

        val pendingIntent = PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Create segments for the delivery journey
        val segments = createDeliverySegments(status)

        // Create the ProgressStyle notification
        val progressStyle = Notification.ProgressStyle()
            .setProgress(currentProgress)
            .setProgressTrackerIcon(
                Icon.createWithResource(
                    context,
                    R.drawable.ic_delivery_tracker
                )
            )
            .setProgressSegments(segments)
            .setStyledByProgress(true)

        // Build the notification with ProgressStyle
        val builder = Notification.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_en_route)
            .setContentTitle("Live Delivery Tracking")
            .setContentText(status.description)
            .setSubText(getETA(status))
            .setContentIntent(pendingIntent)
            .setOngoing(status != DeliveryStatus.DELIVERED)
            .setStyle(progressStyle)
            .setWhen(System.currentTimeMillis())
            .setShowWhen(true)
            .setColor(ContextCompat.getColor(context, status.colorRes))

        // Add contextual actions
        addLiveUpdateActions(builder, status)

        return builder.build()
    }

    @RequiresApi(Build.VERSION_CODES.BAKLAVA)
    private fun createDeliverySegments(currentStatus: DeliveryStatus): List<Notification.ProgressStyle.Segment> {
        val allStatuses = DeliveryStatus.getAllStatuses()
        val currentIndex = allStatuses.indexOf(currentStatus)

        return allStatuses.mapIndexed { index, status ->
            val segmentLength = 100 // Equal segments for each stage
            val segmentColor = when {
                index < currentIndex -> ContextCompat.getColor(
                    context,
                    R.color.status_delivered
                ) // Completed
                index == currentIndex -> ContextCompat.getColor(context, status.colorRes) // Current
                else -> Color.GRAY // Pending
            }

            Notification.ProgressStyle.Segment(segmentLength)
                .setColor(segmentColor)
        }
    }

    private fun addLiveUpdateActions(builder: Notification.Builder, status: DeliveryStatus) {
        when (status) {
            DeliveryStatus.CONFIRMED -> {
                val viewAction = createAction("View Order", R.drawable.ic_view)
                builder.addAction(viewAction)
            }

            DeliveryStatus.PREPARING -> {
                val modifyAction = createAction("Modify Order", R.drawable.ic_edit)
                val trackAction = createAction("Track Progress", R.drawable.ic_view)
                builder.addAction(modifyAction)
                builder.addAction(trackAction)
            }

            DeliveryStatus.EN_ROUTE -> {
                val trackAction = createAction("Track Driver", R.drawable.ic_location)
                val callAction = createAction("Call Driver", R.drawable.ic_call)
                builder.addAction(trackAction)
                builder.addAction(callAction)
            }

            DeliveryStatus.DELIVERED -> {
                val rateAction = createAction("Rate Order", R.drawable.ic_rate)
                builder.addAction(rateAction)
            }
        }
    }

    private fun createAction(title: String, iconRes: Int): Notification.Action {
        val intent = Intent(context, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            context, title.hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return Notification.Action.Builder(
            Icon.createWithResource(context, iconRes),
            title,
            pendingIntent
        ).build()
    }

    private fun getETA(status: DeliveryStatus): String {
        return if (status.estimatedMinutes > 0) {
            val calendar = Calendar.getInstance()
            calendar.add(Calendar.MINUTE, status.estimatedMinutes)
            val formatter = SimpleDateFormat("h:mm a", Locale.getDefault())
            "ETA: ${formatter.format(calendar.time)}"
        } else {
            "Delivered!"
        }
    }

    /**
     * Fallback notification for devices running API < 36
     * Uses enhanced NotificationCompat features to simulate Live Updates appearance
     */
    fun buildFallbackNotification(
        status: DeliveryStatus,
        channelId: String,
        currentProgress: Int = 0,
    ): Notification {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }

        val pendingIntent = PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val progressText = buildProgressText(status)

        return NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_en_route)
            .setContentTitle("🚚 Live Delivery Tracking")
            .setContentText("${status.displayName} • ${status.description}")
            .setSubText(getETA(status))
            .setContentIntent(pendingIntent)
            .setOngoing(status != DeliveryStatus.DELIVERED)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setColor(ContextCompat.getColor(context, status.colorRes))
            .setProgress(400, currentProgress, false) // Total journey progress
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .bigText(progressText)
                    .setBigContentTitle("🚚 Live Delivery Tracking")
                    .setSummaryText(getETA(status))
            )
            .setWhen(System.currentTimeMillis())
            .setShowWhen(true)
            .build()
    }

    private fun buildProgressText(currentStatus: DeliveryStatus): String {
        val allStatuses = DeliveryStatus.getAllStatuses()
        val currentIndex = allStatuses.indexOf(currentStatus)

        return buildString {
            appendLine("📍 ${currentStatus.displayName}")
            appendLine(currentStatus.description)
            appendLine()

            // Visual progress representation
            appendLine("Journey Progress:")
            val progressLine = buildString {
                allStatuses.forEachIndexed { index, _ ->
                    when {
                        index < currentIndex -> append("●━━")
                        index == currentIndex -> append("◉━━")
                        else -> append("○━━")
                    }
                }
                if (endsWith("━━")) {
                    delete(length - 2, length)
                }
            }
            appendLine(progressLine)
            appendLine()

            // Status list
            allStatuses.forEachIndexed { index, status ->
                val icon = when {
                    index < currentIndex -> "✅"
                    index == currentIndex -> "🔄"
                    else -> "⏳"
                }

                val timeInfo = if (index == currentIndex && status.estimatedMinutes > 0) {
                    " (${getETA(status)})"
                } else if (index < currentIndex) {
                    " ✓"
                } else ""

                appendLine("$icon ${status.displayName}$timeInfo")
            }
        }
    }
}