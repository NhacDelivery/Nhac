package com.feentzs.nhac

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.os.Bundle

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.feentzs.nhac/live_notification"
    private lateinit var liveNotificationManager: LiveNotificationManager
    private lateinit var channel: MethodChannel
    private var pendingPedidoId: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        pendingPedidoId = intent?.getStringExtra("pedidoId")
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        pendingPedidoId = intent.getStringExtra("pedidoId")
        if (::channel.isInitialized && pendingPedidoId != null) {
            channel.invokeMethod("openOrder", pendingPedidoId)
            pendingPedidoId = null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        liveNotificationManager = LiveNotificationManager(this)

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "consumePendingOrder" -> {
                    result.success(pendingPedidoId)
                    pendingPedidoId = null
                }
                "showLiveNotification", "updateLiveNotification" -> {
                    val pedidoId = call.argument<String>("pedidoId") ?: ""
                    val nomeProduto = call.argument<String>("nomeProduto") ?: "Seu pedido"
                    val status = call.argument<String>("status") ?: ""
                    val tempoEstimado = call.argument<String>("tempoEstimado") ?: ""
                    val progresso = call.argument<Int>("progresso") ?: 0

                    if (call.method == "showLiveNotification") {
                        liveNotificationManager.showLiveNotification(pedidoId, nomeProduto, status, tempoEstimado, progresso)
                    } else {
                        liveNotificationManager.updateLiveNotification(pedidoId, nomeProduto, status, tempoEstimado, progresso)
                    }
                    result.success(null)
                }
                "cancelLiveNotification" -> {
                    val pedidoId = call.argument<String>("pedidoId") ?: ""
                    liveNotificationManager.cancelLiveNotification(pedidoId)
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
