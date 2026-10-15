import 'package:nhac/services/shared_get.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:nhac/models/produto/produtos.dart';
import 'package:nhac/services/api_client.dart';
import 'package:nhac/utils/safe_parse_helpers.dart';

class PaginaProdutos {
  final List<ProdutosModel> produtos;
  final bool temMais;
  const PaginaProdutos(this.produtos, this.temMais);
}

class ProdutoRepository {
  final Dio _dio;

  ProdutoRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  Future<List<String>> buscarCategorias() async {
    final r = await SharedGet.forClient(
      _dio,
    ).get(_dio, '/produtos/categorias', validity: const Duration(seconds: 30));
    return (r.data as List)
        .map((v) => v.toString())
        .where((v) => v.trim().isNotEmpty)
        .toSet()
        .toList();
  }

  Future<ProdutosModel> buscarPorId(String id) async {
    final response = await _dio.get('/produtos/${Uri.encodeComponent(id)}');
    return ProdutosModel.fromMap(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<List<ProdutosModel>> buscarPromocoes() async {
    try {
      final response = await SharedGet.forClient(_dio).get(
        _dio,
        '/produtos/cards/promocoes',
        queryParameters: {'page': 0, 'size': 10, 'sort': 'id,asc'},
        validity: const Duration(minutes: 2),
      );
      return extrairLista(response.data)
          .map((map) => ProdutosModel.fromMap(map))
          .where(
            (p) => p.percentualDesconto > 0 && p.preco < 20 && p.lojaAberta,
          )
          .toList();
    } catch (e) {
      throw Exception("Erro ao buscar promoções: $e");
    }
  }

  Future<List<ProdutosModel>> buscarNecessidades() async {
    try {
      final response = await SharedGet.forClient(_dio)
          .get(_dio, '/produtos/cards', queryParameters: {'size': 50});
      final List<dynamic> conteudo = extrairLista(response.data);
      return conteudo.map((map) => ProdutosModel.fromMap(map)).toList();
    } catch (e) {
      throw Exception("Erro ao buscar necessidades: $e");
    }
  }

  Future<List<ProdutosModel>> buscarPorCategoria(
    String categoria, {
    int page = 0,
    int size = 50,
  }) async {
    try {
      final response = await SharedGet.forClient(_dio).get(
        _dio,
        '/produtos/cards',
        queryParameters: {
          'categoriaMenu': categoria,
          'page': page,
          'size': size,
          'sort': 'id,asc',
        },
      );
      final List<dynamic> conteudo = extrairLista(response.data);
      return conteudo.map((map) => ProdutosModel.fromMap(map)).toList();
    } catch (e) {
      debugPrint("Erro ao buscar por categoria: $e");
      rethrow;
    }
  }

  Future<PaginaProdutos> buscarPaginaPorLoja(
    String lojaId, {
    int page = 0,
    int size = 50,
    String filtro = 'Todos',
  }) async {
    final response = await SharedGet.forClient(_dio).get(
      _dio,
      filtro == 'Todos'
          ? '/produtos/cards'
          : '/lojas/${Uri.encodeComponent(lojaId)}/catalogo',
      queryParameters: {
        if (filtro != 'Todos') 'filtro': filtro,
        'lojaId': lojaId,
        'page': page,
        'size': size,
        if (filtro == 'Todos') 'sort': 'id,asc',
      },
    );
    final lista = extrairLista(response.data);
    final data = response.data;
    return PaginaProdutos(
      lista.map((map) => ProdutosModel.fromMap(map)).toList(),
      lista.isNotEmpty && data is Map && data['last'] == false,
    );
  }

  Future<List<ProdutosModel>> buscarPorLoja(String lojaId) async {
    try {
      final produtos = <ProdutosModel>[];
      var pagina = 0;
      while (true) {
        final response = await SharedGet.forClient(_dio).get(
          _dio,
          '/produtos/cards',
          queryParameters: {
            'lojaId': lojaId,
            'page': pagina,
            'size': 50,
            'sort': 'id,asc',
          },
        );
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
      rethrow;
    }
  }

  Future<List<ProdutosModel>> buscarProdutosPorNome(
    String termo, {
    int page = 0,
    int size = 20,
  }) async {
    try {
      final response = await SharedGet.forClient(_dio).get(
        _dio,
        '/produtos/cards',
        queryParameters: {
          'nome': termo,
          'page': page,
          'size': size,
          'sort': 'id,asc',
        },
      );
      final List<dynamic> conteudo = extrairLista(response.data);
      return conteudo.map((map) => ProdutosModel.fromMap(map)).toList();
    } catch (e) {
      debugPrint("Erro ao buscar produtos: $e");
      rethrow;
    }
  }
}
