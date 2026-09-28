package com.vamsi.livenotifications.service

import android.content.Intent
import android.os.IBinder
import android.util.Log
import androidx.core.content.edit
import androidx.lifecycle.LifecycleService
import androidx.lifecycle.lifecycleScope
import com.vamsi.livenotifications.model.DeliveryStatus
import com.vamsi.livenotifications.utils.NotificationHelper
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlin.coroutines.coroutineContext
import kotlin.random.Random

class DeliveryTrackingService : LifecycleService() {

    companion object {
        private const val TAG = "DeliveryTrackingService"
        private const val SEGMENT_UPDATE_DELAY_MS = 3000L // 3 seconds between segment updates
        private const val STATUS_TRANSITION_DELAY_MS = 6000L // 6 seconds between status changes
        private const val RETRY_DELAY_MS = 2000L // 2 seconds retry delay
        private const val MAX_RETRIES = 3
    }

    private lateinit var notificationHelper: NotificationHelper
    private var deliveryJob: Job? = null
    private var currentStatus = DeliveryStatus.CONFIRMED
    private var currentSegmentPoint = 0 // Current point within the segment
    private var retryCount = 0

    override fun onCreate() {
        super.onCreate()
        notificationHelper = NotificationHelper(this)

        // Clear any previous completion flag when service starts
        val prefs = getSharedPreferences("delivery_prefs", MODE_PRIVATE)
        prefs.edit { putBoolean("delivery_completed", false) }

        Log.d(TAG, "Service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        super.onStartCommand(intent, flags, startId)
        Log.d(TAG, "Service started")

        // Start with initial Live Update notification
        val initialProgress = DeliveryStatus.calculateProgress(currentStatus, currentSegmentPoint)
        val initialNotification =
            notificationHelper.createLiveUpdateNotification(currentStatus, initialProgress)
        startForeground(NotificationHelper.NOTIFICATION_ID, initialNotification)

        // Start the delivery simulation
        startDeliverySimulation()

        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent): IBinder? {
        super.onBind(intent)
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "Service destroyed")
        deliveryJob?.cancel()
        notificationHelper.cancelNotification()
    }

    private fun startDeliverySimulation() {
        deliveryJob?.cancel()
        deliveryJob =
            lifecycleScope.launch {
                try {
                    simulateDeliveryJourney()
                } catch (e: CancellationException) {
                    Log.d(TAG, "Delivery simulation cancelled")
                    throw e
                } catch (e: Exception) {
                    Log.e(TAG, "Error in delivery simulation", e)
                    handleUpdateFailure()
                }
            }
    }

    private suspend fun simulateDeliveryJourney() {
        val statuses = DeliveryStatus.getAllStatuses()

        for (status in statuses) {
            if (!coroutineContext.isActive) break

            currentStatus = status
            currentSegmentPoint = 0
            Log.d(TAG, "Starting status: ${status.displayName}")

            // Simulate progress through each point in the current segment
            for (pointIndex in status.progressPoints.indices) {
                if (!coroutineContext.isActive) break

                currentSegmentPoint = pointIndex
                val currentProgress = DeliveryStatus.calculateProgress(status, pointIndex)

                Log.d(
                    TAG,
                    "Progress point $pointIndex for ${status.displayName}, total progress: $currentProgress"
                )

                // Update notification with Live Updates
                updateLiveNotificationWithRetry(status, currentProgress)

                // Wait between segment updates
                if (pointIndex < status.progressPoints.size - 1) {
                    delay(SEGMENT_UPDATE_DELAY_MS)
                }
            }

            // Wait before transitioning to next status (except for the last status)
            if (status != DeliveryStatus.DELIVERED) {
                Log.d(TAG, "Waiting before transitioning from ${status.displayName}")
                delay(STATUS_TRANSITION_DELAY_MS)
            }
        }

        // Auto-stop service after delivery is complete
        delay(8000) // Show delivered status for 8 seconds
        Log.d(TAG, "Delivery journey complete, stopping service")

        // Mark delivery as completed in SharedPreferences
        val prefs = getSharedPreferences("delivery_prefs", MODE_PRIVATE)
        prefs.edit { putBoolean("delivery_completed", true) }

        stopSelf()
    }

    private suspend fun updateLiveNotificationWithRetry(status: DeliveryStatus, progress: Int) {
        retryCount = 0

        while (retryCount <= MAX_RETRIES) {
            try {
                // Simulate potential network/update failure (5% chance for more realistic demo)
                if (simulateNetworkFailure()) {
                    throw Exception("Simulated network failure during Live Update")
                }

                // Create and show Live Update notification
                val notification = notificationHelper.createLiveUpdateNotification(status, progress)
                notificationHelper.showNotification(notification)

                Log.d(
                    TAG,
                    "Successfully updated Live notification for ${status.displayName} at progress $progress"
                )
                retryCount = 0 // Reset retry count on success
                return
            } catch (e: Exception) {
                retryCount++
                Log.w(
                    TAG,
                    "Failed to update Live notification (attempt $retryCount/${MAX_RETRIES + 1}): ${e.message}"
                )

                if (retryCount <= MAX_RETRIES) {
                    Log.d(TAG, "Retrying Live Update in ${RETRY_DELAY_MS}ms...")
                    delay(RETRY_DELAY_MS)
                } else {
                    Log.e(TAG, "Max retries reached for Live Update, using fallback")
                    handleLiveUpdateFailure(status, progress)
                    return
                }
            }
        }
    }

    // Legacy method for backward compatibility
    @Deprecated("Use updateLiveNotificationWithRetry instead")
    private suspend fun updateNotificationWithRetry(status: DeliveryStatus) {
        val progress = DeliveryStatus.calculateProgress(status, currentSegmentPoint)
        updateLiveNotificationWithRetry(status, progress)
    }

    private fun handleLiveUpdateFailure(status: DeliveryStatus, progress: Int) {
        // Show a fallback notification indicating connection issues with Live Updates
        try {
            val fallbackNotification =
                notificationHelper.createLiveUpdateNotification(status, progress)
            notificationHelper.showNotification(fallbackNotification)
            Log.d(TAG, "Showed fallback Live Update notification")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to show fallback Live Update notification", e)
            // Last resort: show basic notification
            try {
                val basicNotification = notificationHelper.createProgressNotification(status)
                notificationHelper.showNotification(basicNotification)
                Log.d(TAG, "Showed basic fallback notification")
            } catch (fallbackError: Exception) {
                Log.e(TAG, "All notification methods failed", fallbackError)
            }
        }
    }

    private fun handleUpdateFailure() {
        val progress = DeliveryStatus.calculateProgress(currentStatus, currentSegmentPoint)
        handleLiveUpdateFailure(currentStatus, progress)
    }

    private fun simulateNetworkFailure(): Boolean {
        // Simulate 5% chance of network failure for more realistic Live Updates demo
        return Random.nextFloat() < 0.05f
    }
}