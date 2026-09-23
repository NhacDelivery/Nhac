// lib/services/chat_socket_service.dart
//
// Canal em tempo real do chat, falando STOMP com o backend.
//
// Contrato do backend (WebSocketConfig + StompAuthChannelInterceptor):
//   - handshake em /ws-native (WebSocket puro, sem SockJS — /ws é o endpoint
//     SockJS, pensado pro painel web)
//   - autenticação no frame CONNECT, header "Authorization: Bearer <token>"
//   - assinar   /topic/conversas/{conversaId}     para receber
//   - publicar  /app/conversas/{conversaId}/enviar  para enviar {"conteudo": "..."}
//   - erros de negócio chegam em /user/queue/erros
//
// Requer a dependência stomp_dart_client no pubspec.yaml.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nhac/globals/app_constants.dart';
import 'package:nhac/models/chat/mensagem_chat.dart';
import 'package:nhac/services/session_storage_service.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

class ChatSocketService {
  StompClient? _client;
  String? _conversaId;

  final _mensagensController = StreamController<MensagemChat>.broadcast();
  final _errosController = StreamController<String>.broadcast();
  final _conectadoController = StreamController<bool>.broadcast();
  bool _disposed = false;

  void _emitMensagem(MensagemChat mensagem) {
    if (!_disposed && !_mensagensController.isClosed) {
      _mensagensController.add(mensagem);
    }
  }

  void _emitErro(String erro) {
    if (!_disposed && !_errosController.isClosed) {
      _errosController.add(erro);
    }
  }

  void _emitConectado(bool conectado) {
    if (!_disposed && !_conectadoController.isClosed) {
      _conectadoController.add(conectado);
    }
  }

  /// Mensagens novas da conversa assinada.
  Stream<MensagemChat> get mensagens => _mensagensController.stream;

  /// Erros de negócio devolvidos pelo backend em /user/queue/erros.
  Stream<String> get erros => _errosController.stream;

  /// true quando o STOMP está conectado; false quando cai.
  Stream<bool> get conectado => _conectadoController.stream;

  bool get isConectado => _client?.connected ?? false;

  /// Deriva a URL do WebSocket a partir da base REST.
  /// 'https://host/api/v1' -> 'wss://host/ws-native'
  static String _urlWebSocket() {
    final uri = Uri.parse(AppConstants.apiBaseUrl);
    final esquema = uri.scheme == 'https' ? 'wss' : 'ws';
    return '$esquema://${uri.authority}/ws-native';
  }

  Future<void> conectar(String conversaId) async {
    if (_disposed || _client != null) return;
    _conversaId = conversaId;

    final token = await SessionStorageService().obterToken();
    if (_disposed || _client != null) return;
    if (token == null || token.isEmpty) {
      _emitErro('Sessão expirada. Entre novamente para conversar.');
      return;
    }

    final headers = {'Authorization': 'Bearer $token'};

    _client = StompClient(
      config: StompConfig(
        url: _urlWebSocket(),
        // O interceptor lê o header do frame CONNECT (stompConnectHeaders).
        // O webSocketConnectHeaders vai junto porque em iOS/Android o
        // handshake aceita headers HTTP e ajuda em proxies.
        stompConnectHeaders: headers,
        webSocketConnectHeaders: headers,
        reconnectDelay: const Duration(seconds: 5),
        heartbeatIncoming: const Duration(seconds: 10),
        heartbeatOutgoing: const Duration(seconds: 10),
        onConnect: _aoConectar,
        onWebSocketError: (dynamic erro) {
          debugPrint('💬 [CHAT WS] erro: $erro');
          _emitConectado(false);
        },
        onStompError: (StompFrame frame) {
          debugPrint('💬 [CHAT STOMP] erro: ${frame.body}');
          _emitErro(
            frame.body?.isNotEmpty == true
                ? frame.body!
                : 'Não foi possível conectar ao chat.',
          );
          _emitConectado(false);
        },
        onDisconnect: (_) => _emitConectado(false),
      ),
    );

    _client!.activate();
  }

  void _aoConectar(StompFrame frame) {
    if (_disposed || _client == null) return;
    final conversaId = _conversaId;
    if (conversaId == null) return;

    _emitConectado(true);

    _client!.subscribe(
      destination: '/topic/conversas/$conversaId',
      callback: (StompFrame mensagem) {
        if (mensagem.body == null || mensagem.body!.isEmpty) return;
        try {
          final mapa = jsonDecode(mensagem.body!) as Map<String, dynamic>;
          _emitMensagem(MensagemChat.fromMap(mapa));
        } catch (e) {
          debugPrint('💬 [CHAT WS] payload inválido: $e');
        }
      },
    );

    _client!.subscribe(
      destination: '/user/queue/erros',
      callback: (StompFrame erro) {
        if (erro.body == null) return;
        try {
          final mapa = jsonDecode(erro.body!) as Map<String, dynamic>;
          _emitErro(
              (mapa['erro'] ?? 'Não foi possível enviar a mensagem.').toString());
        } catch (_) {
          _emitErro('Não foi possível enviar a mensagem.');
        }
      },
    );
  }

  /// Publica a mensagem. Ela volta pelo /topic — não adicionamos na lista
  /// localmente pra não duplicar nem mostrar mensagem que o backend recusou.
  bool enviar(String conteudo) {
    final conversaId = _conversaId;
    final texto = conteudo.trim();
    if (conversaId == null || texto.isEmpty) return false;
    if (!(_client?.connected ?? false)) return false;

    _client!.send(
      destination: '/app/conversas/$conversaId/enviar',
      body: jsonEncode({'conteudo': texto}),
    );
    return true;
  }

  Future<void> desconectar() async {
    final client = _client;
    _client = null;
    _conversaId = null;
    client?.deactivate();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;

    final client = _client;
    _client = null;
    _conversaId = null;
    client?.deactivate();

    _mensagensController.close();
    _errosController.close();
    _conectadoController.close();
  }
}
