// lib/repositories/chat_repository.dart
//
// Parte REST do chat do cliente. O ENVIO de mensagem não passa por aqui —
// é WebSocket (ChatSocketService). Este arquivo só abre a conversa, carrega
// o histórico e marca como lida.

import 'package:dio/dio.dart';
import 'package:nhac/globals/exceptions.dart';
import 'package:nhac/models/chat/mensagem_chat.dart';
import 'package:nhac/models/chat/conversa_resumo.dart';
import 'package:nhac/models/chat/conversa_pessoa_resumo.dart';
import 'package:nhac/services/api_client.dart';

class ChatRepository {
  final Dio _dio;
  ChatRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

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
  Future<List<MensagemChat>> historico(
    String conversaId, {
    int pagina = 0,
    int tamanho = 30,
  }) async {
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

  /// GET /conversas - lista de conversas ativas do cliente.
  Future<List<ConversaResumo>> listarConversas({
    int pagina = 0,
    int tamanho = 20,
  }) async {
    try {
      final conteudo = await _listarPorTipo('LOJA', pagina, tamanho);
      return conteudo
          .map(
            (item) => ConversaResumo.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (e) {
      throw mapException(e);
    }
  }

  /// GET /conversas - conversas com outras pessoas, identificadas como CLIENTE.
  Future<List<ConversaPessoaResumo>> listarConversasPessoas({
    int pagina = 0,
    int tamanho = 20,
  }) async {
    try {
      final conteudo = await _listarPorTipo('CLIENTE', pagina, tamanho);
      return conteudo
          .map(
            (item) =>
                ConversaPessoaResumo.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<List<Map<String, dynamic>>> _listarPorTipo(
    String tipo,
    int pagina,
    int tamanho,
  ) async {
    if (pagina < 0 || tamanho < 1 || tamanho > 100) {
      throw ArgumentError('Use página >= 0 e tamanho entre 1 e 100.');
    }
    final inicio = pagina * tamanho;
    final conversas = <Map<String, dynamic>>[];
    var paginaServidor = 0;
    // O backend pagina lojas e pessoas juntas. Pagina cada aba depois do filtro
    // para não ocultar conversas quando outra categoria ocupa a primeira página.
    while (conversas.length < inicio + tamanho) {
      final response = await _dio.get(
        '/conversas',
        queryParameters: {'page': paginaServidor, 'size': 100},
      );
      final dados = Map<String, dynamic>.from(response.data as Map);
      final conteudo = dados['content'] as List;
      conversas.addAll(
        conteudo
            .map((item) => Map<String, dynamic>.from(item as Map))
            .where((item) => item['tipo'] == tipo),
      );
      if (dados['last'] == true || conteudo.isEmpty) break;
      paginaServidor++;
    }
    return conversas.skip(inicio).take(tamanho).toList();
  }
}
