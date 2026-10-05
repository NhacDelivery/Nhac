import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:nhac/services/notificacao_historico_service.dart';
import 'package:nhac/globals/router.dart';
import 'package:flutter/services.dart';
import 'package:nhac/models/pedido/status_pedido.dart';
import 'package:nhac/services/session_storage_service.dart';

class PushNotificationService {
  static String? pendingPedidoId;
  static const MethodChannel _nativeChannel = MethodChannel('com.feentzs.nhac/live_notification');
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final AuthService _authService;

  PushNotificationService(this._authService);

  static String? pendingStatus;

  void _abrirPedido(String? pedidoId, {String? status}) {
    if (pedidoId == null || pedidoId.isEmpty) return;
    if (!_authService.isAuthenticated ||
        appRouter.routeInformationProvider.value.uri.path == '/splash') {
      pendingPedidoId = pedidoId;
      pendingStatus = status;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_authService.isAuthenticated) {
        if (status?.toUpperCase() == 'ENTREGUE') {
          appRouter.go('/pedido-entregue?pedidoId=${Uri.encodeQueryComponent(pedidoId)}');
        } else {
          appRouter.go('/rastreio?pedidoId=${Uri.encodeQueryComponent(pedidoId)}');
        }
      }
    });
  }

  void _abrirPedidoPendenteAposLogin() {
    final pedidoId = pendingPedidoId;
    final status = pendingStatus;
    if (pedidoId == null || !_authService.isAuthenticated ||
        appRouter.routeInformationProvider.value.uri.path == '/splash') {
      return;
    }
    pendingPedidoId = null;
    pendingStatus = null;
    _abrirPedido(pedidoId, status: status);
  }

  final AndroidNotificationChannel _androidChannel = const AndroidNotificationChannel(
    'nhac_high_importance_channel', 
    'Notificações de Pedidos', 
    description: 'Avisos importantes sobre o estado do seu pedido.',
    importance: Importance.max, 
    playSound: true,
    enableVibration: true,
  );

  Future<void> initialize() async {
    _authService.addListener(_abrirPedidoPendenteAposLogin);
    _nativeChannel.setMethodCallHandler((call) async {
      if (call.method == 'openOrder') _abrirPedido(call.arguments?.toString());
    });
    try {
      _abrirPedido(await _nativeChannel.invokeMethod<String>('consumePendingOrder'));
    } on MissingPluginException {
      // A implementação nativa só existe no Android.
    }
    NotificationSettings settings = await _fcm.requestPermission();

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('Permissão de notificações concedida!');

      String? token = await _fcm.getToken();
      if (token != null) {
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
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null && payload.startsWith('ENTREGUE:')) {
            _abrirPedido(payload.substring('ENTREGUE:'.length), status: 'ENTREGUE');
          } else {
            _abrirPedido(payload);
          }
        },
      );

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        registrarMensagem(message, usuarioId: _authService.usuarioId);
        final status = message.data['status']?.toString();
        _abrirPedido(message.data['pedidoId']?.toString(), status: status);
      });
      final inicial = await _fcm.getInitialMessage();
      if (inicial != null) {
        await registrarMensagem(inicial, usuarioId: _authService.usuarioId);
        final status = inicial.data['status']?.toString();
        _abrirPedido(inicial.data['pedidoId']?.toString(), status: status);
      }

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        registrarMensagem(message, usuarioId: _authService.usuarioId);
        RemoteNotification? notification = message.notification;
        AndroidNotification? android = message.notification?.android;

        if (notification != null && android != null) {
          final isEntregue = message.data['status']?.toString().toUpperCase() == 'ENTREGUE';
          final pid = message.data['pedidoId']?.toString() ?? '';
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
            payload: isEntregue ? 'ENTREGUE:$pid' : pid,
          );
        }
      });
    }
  }

  static Future<void> registrarMensagem(
    RemoteMessage message, {
    String? usuarioId,
  }) async {
    try {
      final contaAtual =
          usuarioId ?? await SessionStorageService().obterUsuarioId();
      final destinatario = message.data['usuarioId']?.toString();
      if (contaAtual == null ||
          (destinatario != null && destinatario != contaAtual)) {
        return;
      }
      final pedidoId = message.data['pedidoId']?.toString();
      final status = StatusPedido.fromApi(message.data['status']?.toString());
      final titulo = message.notification?.title ??
          message.data['titulo']?.toString() ??
          message.data['title']?.toString();
      final corpo = message.notification?.body ??
          message.data['corpo']?.toString() ??
          message.data['body']?.toString();
      if (pedidoId != null &&
          pedidoId.isNotEmpty &&
          status != StatusPedido.desconhecido) {
        await NotificacaoHistoricoService.registrarStatus(
          contaAtual,
          pedidoId,
          status,
          titulo: titulo,
          corpo: corpo,
          recebidaEm: message.sentTime,
        );
      } else if (titulo != null) {
        await NotificacaoHistoricoService.registrar(
          contaAtual,
          NotificacaoRegistrada(
            message.messageId ??
                '${pedidoId ?? "aviso"}:${message.sentTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch}',
            titulo,
            corpo ?? '',
            message.sentTime ?? DateTime.now(),
            pedidoId: pedidoId,
          ),
        );
      }
    } catch (e) {
      debugPrint('Não foi possível salvar a notificação recebida: $e');
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
