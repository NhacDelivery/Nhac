package com.vamsi.livenotifications

import android.Manifest
import android.app.ActivityManager
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.core.content.edit
import com.vamsi.livenotifications.service.DeliveryTrackingService
import com.vamsi.livenotifications.ui.theme.LiveNotificationsTheme
import kotlinx.coroutines.delay

class MainActivity : ComponentActivity() {
    private var isDeliveryActive by mutableStateOf(false)

    private val requestPermissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { isGranted: Boolean ->
            if (isGranted) {
                startDeliveryTracking()
            } else {
                showToast("Notification permission is required for this demo")
            }
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        setContent {
            LiveNotificationsTheme {
                // Add a periodic check for delivery completion
                LaunchedEffect(isDeliveryActive) {
                    if (isDeliveryActive) {
                        while (isDeliveryActive) {
                            delay(2000L) // Check every 2 seconds
                            checkDeliveryState()
                        }
                    }
                }

                MainScreen(
                    isDeliveryActive = isDeliveryActive,
                    onStartDelivery = { handleStartDelivery() },
                    onStopDelivery = { handleStopDelivery() }
                )
            }
        }
    }

    override fun onResume() {
        super.onResume()
        // Check delivery state from SharedPreferences and service running status
        checkDeliveryState()
    }

    private fun checkDeliveryState() {
        val prefs = getSharedPreferences("delivery_prefs", MODE_PRIVATE)
        val isDeliveryCompleted = prefs.getBoolean("delivery_completed", false)

        if (isDeliveryCompleted) {
            // Reset the completion flag and update UI
            prefs.edit { putBoolean("delivery_completed", false) }
            isDeliveryActive = false
            showToast("Delivery completed!")
        } else if (isDeliveryActive && !isServiceRunning()) {
            // Service stopped but completion wasn't marked - likely a crash or force stop
            isDeliveryActive = false
        }
    }

    override fun onDestroy() {
        super.onDestroy()
    }

    private fun isServiceRunning(): Boolean {
        val activityManager =
            getSystemService(ACTIVITY_SERVICE) as ActivityManager
        @Suppress("DEPRECATION")
        for (service in activityManager.getRunningServices(Integer.MAX_VALUE)) {
            if (DeliveryTrackingService::class.java.name == service.service.className) {
                return true
            }
        }
        return false
    }

    private fun handleStartDelivery() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            when (PackageManager.PERMISSION_GRANTED) {
                ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) -> {
                    startDeliveryTracking()
                }

                else -> {
                    requestPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                }
            }
        } else {
            startDeliveryTracking()
        }
    }

    private fun handleStopDelivery() {
        stopService(Intent(this, DeliveryTrackingService::class.java))
        isDeliveryActive = false
        showToast("Delivery tracking stopped")
    }

    private fun startDeliveryTracking() {
        // Clear any previous completion flag
        val prefs = getSharedPreferences("delivery_prefs", MODE_PRIVATE)
        prefs.edit { putBoolean("delivery_completed", false) }

        val serviceIntent = Intent(this, DeliveryTrackingService::class.java)
        startForegroundService(serviceIntent)
        isDeliveryActive = true
        showToast("Demo delivery started!")
    }

    private fun showToast(message: String) {
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
    }
}

@Composable
fun MainScreen(isDeliveryActive: Boolean, onStartDelivery: () -> Unit, onStopDelivery: () -> Unit) {
    Surface(modifier = Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(24.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = "Live Notifications Demo",
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier.padding(bottom = 16.dp)
            )

            Text(
                text =
                    "Experience Android 16's Live Updates with real-time progress tracking. This demo uses Notification.ProgressStyle to show a food delivery journey with segments and progress points.",
                fontSize = 16.sp,
                textAlign = TextAlign.Center,
                color = MaterialTheme.colorScheme.onBackground,
                modifier = Modifier.padding(bottom = 32.dp),
                lineHeight = 20.sp
            )

            if (isDeliveryActive) {
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 24.dp),
                    colors =
                        CardDefaults.cardColors(
                            containerColor = MaterialTheme.colorScheme.primaryContainer
                        ),
                    shape = RoundedCornerShape(12.dp),
                    elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
                ) {
                    Column(
                        modifier = Modifier.padding(16.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text(
                            text = "🚚 Delivery in Progress",
                            fontSize = 18.sp,
                            fontWeight = FontWeight.Medium,
                            color = MaterialTheme.colorScheme.onPrimaryContainer
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text =
                                "Check your notification panel to see real-time progress updates!",
                            fontSize = 14.sp,
                            textAlign = TextAlign.Center,
                            color = MaterialTheme.colorScheme.onPrimaryContainer,
                            lineHeight = 18.sp
                        )
                    }
                }
            }

            Button(
                onClick = if (isDeliveryActive) onStopDelivery else onStartDelivery,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp),
                shape = RoundedCornerShape(12.dp),
                colors =
                    ButtonDefaults.buttonColors(
                        containerColor =
                            if (isDeliveryActive) MaterialTheme.colorScheme.error
                            else MaterialTheme.colorScheme.primary
                    ),
                elevation = ButtonDefaults.buttonElevation(defaultElevation = 4.dp)
            ) {
                Text(
                    text = if (isDeliveryActive) "Stop Delivery" else "Start Demo Delivery",
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Medium,
                    color = MaterialTheme.colorScheme.onPrimary
                )
            }

            if (!isDeliveryActive) {
                Spacer(modifier = Modifier.height(32.dp))
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors =
                        CardDefaults.cardColors(
                            containerColor =
                                MaterialTheme.colorScheme.surfaceVariant.copy(
                                    alpha = 0.3f
                                )
                        ),
                    shape = RoundedCornerShape(12.dp),
                    elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text(
                            text = "Features demonstrated:",
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Medium,
                            color = MaterialTheme.colorScheme.onSurface,
                            modifier = Modifier.padding(bottom = 8.dp)
                        )
                        Text(
                            text =
                                "• Android 16 Notification.ProgressStyle API\n" +
                                    "• Live Updates with progress segments\n" +
                                    "• Real-time progress points tracking\n" +
                                    "• Dynamic status transitions\n" +
                                    "• Contextual action buttons\n" +
                                    "• Resilient update handling",
                            fontSize = 14.sp,
                            textAlign = TextAlign.Start,
                            color = MaterialTheme.colorScheme.onSurface,
                            lineHeight = 20.sp
                        )
                    }
                }
            }
        }
    }
}
