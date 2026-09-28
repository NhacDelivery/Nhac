import 'package:nhac/models/usuario/metodos_pagamento_model.dart';


class PagamentoRepository {
  // final _dio = ApiClient().dio;

  Future<List<MetodosPagamentoModel>> buscarPagamentos(String usuarioId) async {
    // API não implementada no backend ainda
    return [];
  }

  Future<MetodosPagamentoModel> adicionarPagamento(String usuarioId, MetodosPagamentoModel metodo) async {
    throw Exception('Funcionalidade de pagamentos salvos temporariamente indisponível');
  }

  Future<void> removerPagamento(String usuarioId, String pagamentoId) async {
    throw Exception('Funcionalidade de pagamentos salvos temporariamente indisponível');
  }

  Future<void> definirComoPadrao(String usuarioId, String pagamentoId) async {
    throw Exception('Funcionalidade de pagamentos salvos temporariamente indisponível');
  }
}
