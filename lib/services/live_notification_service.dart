import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class LiveNotificationService {
  static const MethodChannel _channel = MethodChannel('com.feentzs.nhac/live_notification');

  static Future<void> showLiveNotification({
    required String pedidoId,
    required String nomeProduto,
    required String status,
    required String tempoEstimado,
    required int progresso,
  }) async {
    try {
      await _channel.invokeMethod('showLiveNotification', {
        'pedidoId': pedidoId,
        'nomeProduto': nomeProduto,
        'status': status,
        'tempoEstimado': tempoEstimado,
        'progresso': progresso,
      });
    } on PlatformException catch (e) {
      debugPrint("Failed to show live notification: '${e.message}'.");
    }
  }

  static Future<void> updateLiveNotification({
    required String pedidoId,
    required String nomeProduto,
    required String status,
    required String tempoEstimado,
    required int progresso,
  }) async {
    try {
      await _channel.invokeMethod('updateLiveNotification', {
        'pedidoId': pedidoId,
        'nomeProduto': nomeProduto,
        'status': status,
        'tempoEstimado': tempoEstimado,
        'progresso': progresso,
      });
    } on PlatformException catch (e) {
      debugPrint("Failed to update live notification: '${e.message}'.");
    }
  }

  static Future<void> cancelLiveNotification() async {
    try {
      await _channel.invokeMethod('cancelLiveNotification');
    } on PlatformException catch (e) {
      debugPrint("Failed to cancel live notification: '${e.message}'.");
    }
  }
}
