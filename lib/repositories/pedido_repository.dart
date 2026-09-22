import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:nhac/globals/exceptions.dart';
import 'package:nhac/models/pedido/criar_pedido_request.dart';
import 'package:nhac/models/pedido/pedido_criado_response.dart';
import 'package:nhac/models/pedido/pedido_resumo_model.dart';
import 'package:nhac/models/pedido_model.dart';
import 'package:nhac/services/api_client.dart';

class PedidoRepository {
  final Dio _dio;

  PedidoRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  Future<PedidoCriadoResponse> finalizarPedido(
    CriarPedidoRequest pedido, {
    required String idempotencyKey,
  }) async {
    try {
      final response = await _dio.post(
        '/pedidos',
        data: pedido.toMap(),
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return PedidoCriadoResponse.fromMap(
          Map<String, dynamic>.from(response.data as Map),
          replay: response.statusCode == 200,
        );
      }
      throw Exception('Falha ao criar o pedido. Tente novamente.');
    } on DioException catch (e) {
      final data = e.response?.data;
      if ((e.response?.statusCode == 400 ||
              e.response?.statusCode == 409 ||
              e.response?.statusCode == 422) &&
          data is Map) {
        final message = data['message']?.toString() ?? '';
        final code = data['error']?.toString();
        final title = data['title']?.toString() ??
            (code == 'IDEMPOTENCIA_CONFLITO'
                ? 'Checkout alterado'
                : message.toLowerCase().contains('fechada')
                    ? 'Loja fechada'
                    : 'Não foi possível finalizar');
        final details = data['details'];
        throw CustomCheckoutException(
          message: message.isNotEmpty
              ? message
              : 'Não foi possível finalizar o pedido.',
          title: title,
          code: code,
          produtoId: details is Map ? details['produtoId']?.toString() : null,
          suggestions: data['suggestions'] is List
              ? List<dynamic>.from(data['suggestions'] as List)
              : null,
        );
      }
      throw mapException(e);
    }
  }

  Future<PedidoModel> buscarPedidoPorId(String pedidoId) async {
    try {
      final response = await _dio.get('/pedidos/$pedidoId');
      return PedidoModel.fromMap(
        Map<String, dynamic>.from(response.data as Map),
      );
    } on DioException catch (e) {
      throw mapException(e);
    }
  }

  Future<void> cancelarPedido(String pedidoId) async {
    try {
      await _dio.patch('/pedidos/$pedidoId/cancelar');
    } on DioException catch (e) {
      throw mapException(e);
    }
  }

  Future<Map<String, dynamic>> buscarEstatisticas(String usuarioId) async {
    try {
      final response = await _dio.get('/usuarios/$usuarioId/estatisticas');
      if (response.statusCode == 200 && response.data != null) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      return {
        'totalPedidos': 0,
        'lojasFavoritadas': 0,
        'cuponsResgatados': 0,
      };
    } on DioException catch (e) {
      debugPrint('Erro ao buscar estatísticas: ${e.message ?? ''}');
      return {
        'totalPedidos': 0,
        'lojasFavoritadas': 0,
        'cuponsResgatados': 0,
      };
    }
  }

  Future<List<PedidoResumoModel>> buscarHistorico({
    int page = 0,
    int size = 10,
  }) async {
    try {
      final response = await _dio.get(
        '/pedidos',
        queryParameters: {
          'page': page,
          'size': size,
          'sort': 'criadoEm,desc',
        },
      );
      final data = response.data;
      final List<dynamic> content =
          data is Map ? (data['content'] as List? ?? const []) : const [];
      return content
          .map((map) => PedidoResumoModel.fromMap(
                Map<String, dynamic>.from(map as Map),
              ))
          .toList();
    } on DioException catch (e) {
      throw mapException(e);
    }
  }
}
