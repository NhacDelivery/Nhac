package com.feentzs.nhac

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.feentzs.nhac/live_notification"
    private lateinit var liveNotificationManager: LiveNotificationManager

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        liveNotificationManager = LiveNotificationManager(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
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
