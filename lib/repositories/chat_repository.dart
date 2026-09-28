// lib/repositories/chat_repository.dart
//
// Parte REST do chat do cliente. O ENVIO de mensagem não passa por aqui —
// é WebSocket (ChatSocketService). Este arquivo só abre a conversa, carrega
// o histórico e marca como lida.

import 'package:nhac/globals/exceptions.dart';
import 'package:nhac/models/chat/mensagem_chat.dart';
import 'package:nhac/services/api_client.dart';

class ChatRepository {
  final _dio = ApiClient().dio;

  /// POST /conversas/lojas/{lojaId} — idempotente, devolve o id da conversa.
  ///
  /// O backend pode responder com texto ou objeto contendo o id; por isso a
  /// resposta chega como texto e não como JSON. O trecho abaixo aceita os
  /// dois formatos pra não quebrar se o contrato virar um objeto depois.
  Future<String> abrirConversaComLoja(String lojaId) async {
    try {
      final response = await _dio.post('/conversas/lojas/$lojaId');
      final data = response.data;
      if (data is Map) {
        return (data['id'] ?? data['conversaId']).toString();
      }
      return data.toString().replaceAll('"', '').trim();
    } catch (e) {
      throw mapException(e);
    }
  }

  /// GET /conversas/{conversaId}/mensagens — página mais recente primeiro.
  /// Devolvemos já invertido (mais antiga primeiro), que é a ordem da tela.
  Future<List<MensagemChat>> historico(String conversaId,
      {int pagina = 0, int tamanho = 30}) async {
    try {
      final response = await _dio.get(
        '/conversas/$conversaId/mensagens',
        queryParameters: {'page': pagina, 'size': tamanho},
      );
      final conteudo = (response.data['content'] as List?) ?? const [];
      final mensagens = conteudo
          .map((item) => MensagemChat.fromMap(Map<String, dynamic>.from(item)))
          .toList();
      return mensagens.reversed.toList();
    } catch (e) {
      throw mapException(e);
    }
  }

  /// PATCH /conversas/{conversaId}/lida — zera o contador do lado do cliente.
  /// Falha aqui é silenciosa de propósito: não vale travar a tela de chat
  /// porque um contador não zerou.
  Future<void> marcarComoLida(String conversaId) async {
    try {
      await _dio.patch('/conversas/$conversaId/lida');
    } catch (_) {
      // ignorado
    }
  }
}
