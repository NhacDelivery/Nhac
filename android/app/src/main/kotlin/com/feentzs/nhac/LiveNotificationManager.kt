package com.feentzs.nhac

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.graphics.drawable.IconCompat

class LiveNotificationManager(private val context: Context) {
    private val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private val CHANNEL_ID = "live_tracking_channel"

    init {
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Rastreio de Pedidos (Live)",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Notificações em tempo real sobre o seu pedido"
            }
            notificationManager.createNotificationChannel(channel)
        }
    }

    fun showLiveNotification(pedidoId: String, nomeProduto: String, status: String, tempoEstimado: String, stageIndex: Int) {
        val notification = buildNotification(pedidoId, nomeProduto, status, tempoEstimado, stageIndex)
        notificationManager.notify(pedidoId.hashCode(), notification)
    }

    fun updateLiveNotification(pedidoId: String, nomeProduto: String, status: String, tempoEstimado: String, stageIndex: Int) {
        val notification = buildNotification(pedidoId, nomeProduto, status, tempoEstimado, stageIndex)
        notificationManager.notify(pedidoId.hashCode(), notification)
    }

    fun cancelLiveNotification(pedidoId: String) {
        notificationManager.cancel(pedidoId.hashCode())
    }

    private fun buildNotification(pedidoId: String, nomeProduto: String, status: String, tempoEstimado: String, stageIndex: Int): android.app.Notification {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }

        val pendingIntent = PendingIntent.getActivity(
            context, pedidoId.hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val tempoFormatado = if (tempoEstimado.isNotEmpty() && tempoEstimado != "Entregue") " • Previsão: $tempoEstimado" else ""
        
        // Texto curto para o Status Chip do Android 16
        val shortStatus = if (tempoEstimado.isNotEmpty()) {
            val match = "\\d+".toRegex().find(tempoEstimado)
            if (match != null) "${match.value}m" else status.take(7)
        } else {
            "Nhac!"
        }

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_nhac_chip)
            .setContentTitle(status)
            .setContentText("$nomeProduto$tempoFormatado")
            .setOnlyAlertOnce(true)
            .setOngoing(stageIndex < 4) // 4 is Delivered
            .setContentIntent(pendingIntent)
            .setWhen(System.currentTimeMillis())
            .setShowWhen(true)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)

        // Android 16 (Baklava) Live Update API
        if (Build.VERSION.SDK_INT >= 34) { 
            // A API de requisição do chip de notificação funciona a partir de versões mais recentes da biblioteca Core
            builder.setRequestPromotedOngoing(true) 
            builder.setShortCriticalText(shortStatus) 
        }

        // Action Button: Ver Pedido usando recursos do NotificationCompat
        builder.addAction(
            NotificationCompat.Action.Builder(
                IconCompat.createWithResource(context, android.R.drawable.ic_menu_view), 
                "Ver Pedido", 
                pendingIntent
            ).build()
        )

        // Configuração do Estilo de Progresso Segmentado
        val progressStyle = NotificationCompat.ProgressStyle()
        val segments = mutableListOf<NotificationCompat.ProgressStyle.Segment>()
        
        for (i in 0 until 5) {
            val color = if (i <= stageIndex) Color.parseColor("#FF6961") else Color.GRAY
            // Verifica o suporte de Segmentação no Estilo
            segments.add(NotificationCompat.ProgressStyle.Segment(20).setColor(color))
        }

        // Configuração fallback para Androids anteriores que não suportam ProgressStyle Segmentado
        if (Build.VERSION.SDK_INT >= 35) {
            progressStyle.setProgressSegments(segments)
            builder.setStyle(progressStyle)
        } else {
            builder.setProgress(4, stageIndex, false)
        }

        return builder.build()
    }
}