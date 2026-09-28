import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:nhac/models/produto/avaliacoes.dart';
import 'package:nhac/services/api_client.dart';
import 'package:nhac/utils/safe_parse_helpers.dart';

class AvaliacaoRepository {
  final _dio = ApiClient().dio;

  Future<List<AvaliacoesModel>> buscarAvaliacoes(String lojaId, {int page = 0, int size = 10}) async {
    try {
      final response = await _dio.get('/lojas/$lojaId/avaliacoes', queryParameters: {
        'page': page,
        'size': size,
      });
      if (response.statusCode == 200 && response.data != null) {
        final List data = extrairLista(response.data); 
        return data.map((map) => AvaliacoesModel.fromMap(map, map['id']?.toString() ?? '')).toList();
      }
      return [];
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return [];
      debugPrint("Erro ao buscar avaliações: ${e.message}");
      throw Exception('Falha ao buscar avaliações');
    }
  }

  Future<AvaliacoesModel> criarAvaliacao(String pedidoId, double nota, String comentario) async {
    try {
      final response = await _dio.post('/avaliacoes', data: {
        'pedidoId': pedidoId,
        'nota': nota,
        'comentario': comentario,
      });
      if (response.statusCode == 200 || response.statusCode == 201) {
        final map = response.data;
        return AvaliacoesModel.fromMap(map, map['id']?.toString() ?? '');
      }
      throw Exception('Erro ao criar avaliação');
    } on DioException catch (e) {
      final mensagem = extrairMensagemErro(e.response?.data, fallback: 'Erro ao criar avaliação');
      throw Exception(mensagem);
    }
  }

  Future<Map<String, dynamic>> buscarResumoAvaliacoes(String produtoId) async {
    try {
      final response = await _dio.get('/produtos/$produtoId/avaliacoes/resumo');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        return {
          'media': data['mediaNotas'] ?? 0.0,
          'total': data['totalAvaliacoes'] ?? 0,
        };
      }
      return {'media': 0.0, 'total': 0};
    } on DioException catch (e) {
      debugPrint("Erro ao buscar resumo de avaliações: ${e.message}");
      return {'media': 0.0, 'total': 0};
    }
  }
}
