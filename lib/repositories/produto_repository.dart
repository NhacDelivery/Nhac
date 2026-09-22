import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:nhac/models/produto/produtos.dart';
import 'package:nhac/services/api_client.dart';
import 'package:nhac/utils/safe_parse_helpers.dart';

class ProdutoRepository {
  final Dio _dio;

  ProdutoRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  Future<List<ProdutosModel>> buscarPromocoes() async {
    try {
      final response = await _dio
          .get('/produtos', queryParameters: {'precoMaximo': 20.0, 'size': 50});
      final List<dynamic> conteudo = extrairLista(response.data);
      return conteudo.map((map) => ProdutosModel.fromMap(map)).toList();
    } catch (e) {
      throw Exception("Erro ao buscar promoções: $e");
    }
  }

  Future<List<ProdutosModel>> buscarNecessidades() async {
    try {
      final response =
          await _dio.get('/produtos', queryParameters: {'size': 50});
      final List<dynamic> conteudo = extrairLista(response.data);
      return conteudo.map((map) => ProdutosModel.fromMap(map)).toList();
    } catch (e) {
      throw Exception("Erro ao buscar necessidades: $e");
    }
  }

  Future<List<ProdutosModel>> buscarPorCategoria(String categoria) async {
    try {
      final response = await _dio.get('/produtos',
          queryParameters: {'categoriaMenu': categoria, 'size': 50});
      final List<dynamic> conteudo = extrairLista(response.data);
      return conteudo.map((map) => ProdutosModel.fromMap(map)).toList();
    } catch (e) {
      debugPrint("Erro ao buscar por categoria: $e");
      return [];
    }
  }

  Future<List<ProdutosModel>> buscarPorLoja(String lojaId) async {
    try {
      final produtos = <ProdutosModel>[];
      var pagina = 0;
      while (true) {
        final response = await _dio.get('/produtos', queryParameters: {
          'lojaId': lojaId,
          'page': pagina,
          'size': 50,
          'sort': 'id,asc',
        });
        final conteudo = extrairLista(response.data);
        produtos.addAll(conteudo.map((map) => ProdutosModel.fromMap(map)));
        final data = response.data;
        if (conteudo.isEmpty || data is! Map || data['last'] != false) {
          return produtos;
        }
        pagina++;
      }
    } catch (e) {
      debugPrint("Erro ao buscar produtos da loja: $e");
      return [];
    }
  }

  Future<List<ProdutosModel>> buscarProdutosPorNome(String termo) async {
    try {
      final response = await _dio
          .get('/produtos', queryParameters: {'nome': termo, 'size': 20});
      final List<dynamic> conteudo = extrairLista(response.data);
      return conteudo.map((map) => ProdutosModel.fromMap(map)).toList();
    } catch (e) {
      debugPrint("Erro ao buscar produtos: $e");
      return [];
    }
  }
}
