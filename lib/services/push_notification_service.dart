import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nhac/globals/router.dart';
import 'package:nhac/services/auth_service.dart';

class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  final AuthService _auth;
  String? _usuarioAnterior;
  String? _pedidoPendente;

  PushNotificationService(this._auth);

  static const AndroidNotificationChannel _canal = AndroidNotificationChannel(
    'nhac_high_importance_channel',
    'Notificações de Pedidos',
    description: 'Avisos importantes sobre o estado do seu pedido.',
    importance: Importance.max,
  );

  Future<void> initialize() async {
    final permissoes = await _fcm.requestPermission();
    if (permissoes.authorizationStatus != AuthorizationStatus.authorized &&
        permissoes.authorizationStatus != AuthorizationStatus.provisional) return;

    await _fcm.setForegroundNotificationPresentationOptions(
      alert: false, badge: true, sound: false,
    );
    await _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_canal);
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (resposta) => _abrirPedido(resposta.payload),
    );
    final aberturaLocal = await _local.getNotificationAppLaunchDetails();
    if (aberturaLocal?.didNotificationLaunchApp == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _abrirPedido(aberturaLocal?.notificationResponse?.payload);
      });
    }

    _usuarioAnterior = _auth.usuarioId;
    _auth.addListener(() {
      final atual = _auth.usuarioId;
      if (atual != null && atual != _usuarioAnterior) _registrarTokenAtual();
      if (atual != null && _pedidoPendente != null) {
        final pedido = _pedidoPendente;
        _pedidoPendente = null;
        WidgetsBinding.instance.addPostFrameCallback((_) => _abrirPedido(pedido));
      }
      if (atual == null && _auth.carregado) _pedidoPendente = null;
      _usuarioAnterior = atual;
    });
    _fcm.onTokenRefresh.listen(_registrarToken);
    await _registrarTokenAtual();

    FirebaseMessaging.onMessage.listen((mensagem) async {
      if (_auth.usuarioId == null) return;
      final aviso = mensagem.notification;
      if (aviso == null) return;
      await _local.show(
        id: mensagem.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: aviso.title,
        body: aviso.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'nhac_high_importance_channel', 'Notificações de Pedidos',
            channelDescription: 'Avisos importantes sobre o estado do seu pedido.',
            importance: Importance.max, priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: mensagem.data['pedidoId'],
      );
    });
    FirebaseMessaging.onMessageOpenedApp.listen((mensagem) {
      _abrirPedido(mensagem.data['pedidoId']);
    });
    final inicial = await _fcm.getInitialMessage();
    if (inicial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _abrirPedido(inicial.data['pedidoId']);
      });
    }
  }

  Future<void> _registrarTokenAtual() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) await _registrarToken(token);
    } catch (e) {
      debugPrint('FCM: token indisponível: $e');
    }
  }

  Future<void> _registrarToken(String token) async {
    if (_auth.usuarioId == null) return;
    try {
      await _auth.updateFcmToken(fcmToken: token);
    } catch (e) {
      debugPrint('FCM: não foi possível registrar o dispositivo: $e');
    }
  }

  void _abrirPedido(String? pedidoId) {
    if (pedidoId == null || pedidoId.isEmpty) return;
    if (_auth.usuarioId == null) {
      if (!_auth.carregado) _pedidoPendente = pedidoId;
      return;
    }
    appRouter.go('/rastreio?pedidoId=${Uri.encodeComponent(pedidoId)}');
  }
}
