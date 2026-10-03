import 'package:nhac/services/shared_get.dart';
import 'package:dio/dio.dart';
import 'package:nhac/globals/exceptions.dart';
import 'package:nhac/models/pedido/avaliacao_entregador_model.dart';
import 'package:nhac/models/pedido/criar_pedido_request.dart';
import 'package:nhac/models/pedido/pedido_criado_response.dart';
import 'package:nhac/models/pedido/pedido_resumo_model.dart';
import 'package:nhac/models/pedido/pagamento_pendente_model.dart';
import 'package:nhac/models/pedido_model.dart';
import 'package:nhac/services/api_client.dart';

class PedidoRepository {
  final Dio _dio;

  PedidoRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  void invalidarPedido(String pedidoId) {
    final client = SharedGet.forClient(_dio);
    client.invalidatePath('/pedidos/$pedidoId');
    client.invalidatePath('/pedidos/ativos');
    client.invalidatePath('/pedidos/ativo');
  }

  Future<List<PedidoModel>> buscarPedidosAtivos() async {
    try {
      final response =
          await SharedGet.forClient(_dio).get(_dio, '/pedidos/ativos');
      return (response.data as List)
          .map((item) =>
              PedidoModel.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
    } on DioException catch (e) {
      throw mapException(e);
    }
  }

  Future<PedidoModel?> buscarPedidoAtivo() async {
    try {
      final response =
          await SharedGet.forClient(_dio).get(_dio, '/pedidos/ativo');
      if (response.statusCode == 204 || response.data == null) return null;
      return PedidoModel.fromMap(
          Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (e) {
      throw mapException(e);
    }
  }

  Future<PagamentoPendenteModel> buscarPagamento(String pedidoId) async {
    try {
      final response = await SharedGet.forClient(_dio)
          .get(_dio, '/pedidos/$pedidoId/pagamento');
      return PagamentoPendenteModel.fromMap(
          Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (e) {
      throw mapException(e);
    }
  }

  Future<void> simularPagamentoPix(String pedidoId) async {
    try {
      await _dio.post('/pedidos/$pedidoId/pagamento/simular');
    } on DioException catch (e) {
      throw mapException(e);
    }
  }

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
      if (data is Map &&
          (data['errorCode'] ?? data['error']) == 'PAGAMENTO_INDISPONIVEL' &&
          data['details'] is Map &&
          data['details']['pedidoId'] != null) {
        // Reserva confirmada: abrir a recuperação, sem gerar outro checkout.
        return PedidoCriadoResponse.fromMap(
            {'pedidoId': data['details']['pedidoId'].toString()},
            replay: true);
      }
      if ((e.response?.statusCode == 400 ||
              e.response?.statusCode == 409 ||
              e.response?.statusCode == 422) &&
          data is Map) {
        final message = data['message']?.toString() ?? '';
        final code = (data['errorCode'] ?? data['error'])?.toString();
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
          pedidoAtivoId: code == 'PEDIDO_ATIVO' && details is Map
              ? details['pedidoId']?.toString()
              : null,
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
      final response =
          await SharedGet.forClient(_dio).get(_dio, '/pedidos/$pedidoId');
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
    SharedGet.forClient(_dio)
        .invalidatePath('/usuarios/$usuarioId/estatisticas');
    try {
      final response = await SharedGet.forClient(_dio)
          .get(_dio, '/usuarios/$usuarioId/estatisticas');
      if (response.statusCode != 200 || response.data is! Map) {
        throw StateError('Estatísticas indisponíveis');
      }
      final dados = Map<String, dynamic>.from(response.data as Map);
      for (final campo in [
        'totalPedidos',
        'lojasFavoritadas',
        'cuponsResgatados'
      ]) {
        if (dados[campo] is! num) throw StateError('Estatísticas incompletas');
      }
      return dados;
    } on DioException catch (e) {
      throw mapException(e);
    }
  }

  Future<List<PedidoResumoModel>> buscarHistorico({
    int page = 0,
    int size = 10,
  }) async {
    try {
      final response = await SharedGet.forClient(_dio).get(
        _dio,
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

  Future<void> avaliarEntregador(
    String pedidoId,
    int nota, [
    String? comentario,
  ]) async {
    try {
      await _dio.post(
        '/pedidos/$pedidoId/avaliacao-entregador',
        data: {
          'nota': nota,
          if (comentario != null && comentario.trim().isNotEmpty)
            'comentario': comentario.trim(),
        },
      );
    } on DioException catch (e) {
      throw mapException(e);
    }
  }

  Future<AvaliacaoEntregadorModel?> buscarAvaliacaoEntregador(
      String pedidoId) async {
    try {
      final response = await SharedGet.forClient(_dio)
          .get(_dio, '/pedidos/$pedidoId/avaliacao-entregador');
      if (response.statusCode == 200 && response.data != null) {
        return AvaliacaoEntregadorModel.fromMap(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      throw mapException(e);
    }
  }
}
