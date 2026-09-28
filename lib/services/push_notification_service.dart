import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:nhac/services/auth_service.dart';

class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final AuthService _authService;

  PushNotificationService(this._authService);

  final AndroidNotificationChannel _androidChannel = const AndroidNotificationChannel(
    'nhac_high_importance_channel', 
    'Notificações de Pedidos', 
    description: 'Avisos importantes sobre o estado do seu pedido.',
    importance: Importance.max, 
    playSound: true,
    enableVibration: true,
  );

  Future<void> initialize() async {
    NotificationSettings settings = await _fcm.requestPermission();

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('Permissão de notificações concedida!');

      String? token = await _fcm.getToken();
      if (token != null) {
        debugPrint('MEU FCM TOKEN: $token');
        if (_authService.usuarioId != null) {
          await _guardarTokenNoBancoDeDados(token);
        }
      }

      // Envia FCM token ao backend quando o usuário faz login
      // Cria uma variável para guardar o estado anterior do usuário
      String? lastUserId = _authService.usuarioId;
      _authService.addListener(() async {
        final currentUserId = _authService.usuarioId;
        // Só executa se houver um usuário logado E se ele for diferente do anterior (ou seja, acabou de logar)
        if (currentUserId != null && currentUserId != lastUserId) {
          final fcmToken = await _fcm.getToken();
          if (fcmToken != null) {
            await _guardarTokenNoBancoDeDados(fcmToken);
          }
        }
        
        // Atualiza a referência para a próxima checagem
        lastUserId = currentUserId;
      });

      _fcm.onTokenRefresh.listen((novoToken) {
        _guardarTokenNoBancoDeDados(novoToken);
      });

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);

      const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initSettings = InitializationSettings(android: androidInit);

      await _localNotifications.initialize(
        settings: initSettings, 
      );

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        RemoteNotification? notification = message.notification;
        AndroidNotification? android = message.notification?.android;

        if (notification != null && android != null) {
          _localNotifications.show(
            id:
            notification.hashCode,
            title:
            notification.title,
            body:
            notification.body,
            notificationDetails: 
            NotificationDetails(
              android: AndroidNotificationDetails(
                _androidChannel.id,
                _androidChannel.name,
                channelDescription: _androidChannel.description,
                importance: Importance.max,
                priority: Priority.high,
                icon: '@mipmap/ic_launcher',
              ),
            ),
          );
        }
      });
    }
  }

  Future<void> _guardarTokenNoBancoDeDados(String token) async {
    String? userId = _authService.usuarioId;

    if (userId != null) {
      try {
        await _authService.updateFcmToken(fcmToken: token);
        debugPrint('✅ FCM Token atualizado na API com sucesso!');
      } catch (e) {
        debugPrint('❌ Erro ao guardar o token na API: $e');
      }
    } else {
      debugPrint('Nenhum utilizador logado. O token não foi guardado na base de dados.');
    }
  }
}
