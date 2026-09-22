import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nhac/globals/app_constants.dart';
import 'package:nhac/models/pedido/status_pedido.dart';
import 'package:nhac/services/session_storage_service.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

class PedidoStatusSocketService {
  StompClient? _client;
  String? _pedidoId;

  final _statusController = StreamController<StatusPedido>.broadcast();
  final _conectadoController = StreamController<bool>.broadcast();

  Stream<StatusPedido> get status => _statusController.stream;
  Stream<bool> get conectado => _conectadoController.stream;

  static String _urlWebSocket() {
    final uri = Uri.parse(AppConstants.apiBaseUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return '$scheme://${uri.authority}/ws-native';
  }

  Future<void> conectar(String pedidoId) async {
    if (_client != null) return;
    _pedidoId = pedidoId;

    final token = await SessionStorageService().obterToken();
    if (token == null || token.isEmpty) return;

    final headers = {'Authorization': 'Bearer $token'};
    _client = StompClient(
      config: StompConfig(
        url: _urlWebSocket(),
        stompConnectHeaders: headers,
        webSocketConnectHeaders: headers,
        reconnectDelay: const Duration(seconds: 5),
        heartbeatIncoming: const Duration(seconds: 10),
        heartbeatOutgoing: const Duration(seconds: 10),
        onConnect: (_) {
          _conectadoController.add(true);
          final id = _pedidoId;
          if (id == null) return;
          _client!.subscribe(
            destination: '/topic/pedidos/$id/status',
            callback: (frame) {
              final raw = frame.body?.replaceAll('"', '').trim();
              final parsed = StatusPedido.fromApi(raw);
              if (parsed != StatusPedido.desconhecido) {
                _statusController.add(parsed);
              }
            },
          );
        },
        onDisconnect: (_) => _conectadoController.add(false),
        onWebSocketError: (error) {
          debugPrint('[PEDIDO WS] erro: $error');
          _conectadoController.add(false);
        },
        onStompError: (frame) {
          debugPrint('[PEDIDO STOMP] erro: ${frame.body ?? ''}');
          _conectadoController.add(false);
        },
      ),
    );
    _client!.activate();
  }

  Future<void> desconectar() async {
    _client?.deactivate();
    _client = null;
    _pedidoId = null;
  }

  void dispose() {
    desconectar();
    _statusController.close();
    _conectadoController.close();
  }
}
