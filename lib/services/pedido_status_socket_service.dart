import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nhac/globals/app_constants.dart';
import 'package:nhac/models/pedido/status_pedido.dart';
import 'package:nhac/services/session_storage_service.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

class PedidoStatusSocketService {
  StompClient? _client;
  String? _pedidoId;
  bool _disposed = false;

  final _statusController = StreamController<StatusPedido>.broadcast();
  final _conectadoController = StreamController<bool>.broadcast();

  Stream<StatusPedido> get status => _statusController.stream;
  Stream<bool> get conectado => _conectadoController.stream;

  void _emitStatus(StatusPedido valor) {
    if (!_disposed && !_statusController.isClosed) {
      _statusController.add(valor);
    }
  }

  void _emitConectado(bool valor) {
    if (!_disposed && !_conectadoController.isClosed) {
      _conectadoController.add(valor);
    }
  }

  static String _urlWebSocket() {
    final uri = Uri.parse(AppConstants.apiBaseUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return '$scheme://${uri.authority}/ws-native';
  }

  Future<void> conectar(String pedidoId) async {
    if (_disposed || _client != null) return;
    _pedidoId = pedidoId;

    final token = await SessionStorageService().obterToken();
    if (_disposed || _client != null) return;
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
          if (_disposed) return;
          _emitConectado(true);
          final id = _pedidoId;
          final client = _client;
          if (id == null || client == null) return;
          client.subscribe(
            destination: '/topic/pedidos/$id/status',
            callback: (frame) {
              if (_disposed) return;
              final raw = frame.body?.replaceAll('"', '').trim();
              final parsed = StatusPedido.fromApi(raw);
              if (parsed != StatusPedido.desconhecido) {
                _emitStatus(parsed);
              }
            },
          );
        },
        onDisconnect: (_) => _emitConectado(false),
        onWebSocketError: (error) {
          debugPrint('[PEDIDO WS] erro: $error');
          _emitConectado(false);
        },
        onStompError: (frame) {
          debugPrint('[PEDIDO STOMP] erro: ${frame.body ?? ''}');
          _emitConectado(false);
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
    if (_disposed) return;
    _disposed = true;
    desconectar();
    _statusController.close();
    _conectadoController.close();
  }
}
