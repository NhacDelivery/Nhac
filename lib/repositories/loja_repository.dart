import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:nhac/globals/exceptions.dart';
import 'package:nhac/models/loja/lojas.dart';
import 'package:nhac/services/api_client.dart';
import 'package:nhac/models/entrega/frete_model.dart';
import 'package:nhac/utils/safe_parse_helpers.dart';

class LojaRepository {
  final Dio _dio;

  LojaRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  Future<List<LojasModel>> buscarLojas({int page = 0, int size = 10}) async {
    try {
      final response = await _dio.get(
        '/lojas',
        queryParameters: {'page': page, 'size': size},
      );

      final List<dynamic> conteudo = extrairLista(response.data);
      return conteudo.map((map) => LojasModel.fromMap(map)).toList();
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<LojasModel?> buscarLoja(String lojaId) async {
    try {
      final response = await _dio.get('/lojas/$lojaId');
      return LojasModel.fromMap(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        debugPrint(
            "Loja $lojaId não encontrada (404) — tratando como fechada.");
        return null;
      }
      debugPrint("Erro de rede ao buscar loja $lojaId: $e");
      rethrow;
    } catch (e) {
      debugPrint("Erro inesperado ao buscar loja $lojaId: $e");
      rethrow;
    }
  }

  Future<List<LojasModel>> buscarLojasPorNome(String termo) async {
    final termoBusca = termo.trim();
    if (termoBusca.isEmpty) return [];

    try {
      final response = await _dio.get(
        '/lojas',
        queryParameters: {'nome': termoBusca, 'page': 0, 'size': 50},
      );

      final List<dynamic> conteudo = extrairLista(response.data);
      return conteudo.map((map) => LojasModel.fromMap(map)).toList();
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<void> seguirLoja(String usuarioId, String lojaId) async {
    try {
      await _dio.post('/favoritos', data: {'lojaId': lojaId});
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<void> deixarDeSeguir(String usuarioId, String lojaId) async {
    try {
      await _dio.delete('/favoritos/$lojaId');
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<int> contarSeguidores(String lojaId) async {
    try {
      final response = await _dio.get('/favoritos/lojas/$lojaId/contagem');
      if (response.statusCode == 200) {
        final raw = response.data;
        if (raw is int) return raw;
        if (raw is Map) return safeInt(raw['total']);
        return 0;
      }
      return 0;
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<bool> estaSeguindo(String usuarioId, String lojaId) async {
    try {
      final response = await _dio.get('/usuarios/$usuarioId/seguindo/$lojaId');
      return response.statusCode == 200 && response.data == true;
    } catch (e) {
      return false; // Silenciosamente retorna falso em caso de erro (ex: não logado ou não segue)
    }
  }

  Future<List<LojasModel>> listarLojasFavoritas(
      {int page = 0, int size = 10}) async {
    try {
      final response = await _dio.get(
        '/favoritos',
        queryParameters: {'page': page, 'size': size, 'sort': 'criadoEm,desc'},
      );
      if (response.statusCode == 200 && response.data != null) {
        final List data = response.data['content'] ?? [];
        return data.map((map) {
          return LojasModel(
            id: map['lojaId'] ?? '',
            nome: map['lojaNome'] ?? '',
            imagemUrl: map['lojaImagemUrl'] ?? '',
            descricao: '',
            categoria: '',
            dadosOperacionais: null,
            horarios: null,
            endereco: null,
          );
        }).toList();
      }
      return [];
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<FreteModel> calcularFrete(
    String lojaId, {
    required double lat,
    required double lng,
  }) async {
    try {
      final response = await _dio.post(
        '/lojas/$lojaId/calcular-frete',
        data: {'lat': lat, 'lng': lng},
      );
      return FreteModel.fromMap(
        Map<String, dynamic>.from(response.data as Map),
      );
    } catch (e) {
      throw mapException(e);
    }
  }
}
