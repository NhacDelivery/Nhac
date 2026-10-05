import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nhac/models/usuario/carrinho_model.dart';

class CartRepository {
  static Future<void> _gravacoesPendentes = Future<void>.value();

  static Future<void> _gravar(Future<void> Function() operation) {
    final gravacao = _gravacoesPendentes.then((_) => operation());
    _gravacoesPendentes = gravacao.catchError((Object _) {});
    return gravacao;
  }

  final String? usuarioId;
  CartRepository({this.usuarioId});

  String get _cartKey =>
      usuarioId == null ? '@nhac_cart_items' : '@nhac_cart_items:$usuarioId';

  Future<void> salvarCarrinhoLocal(
    List<CartItemModel> itens, {
    String observacao = '',
  }) {
    final jsonString = json.encode({
      'itens': itens.map((i) => i.toMap()).toList(),
      'observacao': itens.isEmpty ? '' : observacao,
    });
    return _gravar(() async {
      final prefs = await SharedPreferences.getInstance();
      final previous = prefs.getString(_cartKey);
      final current = previous == null ? null : jsonDecode(previous);
      final payload = jsonDecode(jsonString) as Map<String, dynamic>;
      if (current is Map)
        payload['pedidosConsumidos'] = current['pedidosConsumidos'] ?? [];
      if (!await prefs.setString(_cartKey, jsonEncode(payload)))
        throw StateError('Não foi possível salvar o carrinho.');
    });
  }

  Future<List<CartItemModel>> carregarCarrinhoLocal() async {
    await _gravacoesPendentes;
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_cartKey);

      if (jsonString != null && jsonString.isNotEmpty) {
        final decoded = json.decode(jsonString);
        final List<dynamic> decodedList = decoded is List
            ? decoded
            : decoded['itens'];
        return decodedList.map((map) => CartItemModel.fromMap(map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("Erro ao carregar carrinho do cache: $e");
      return [];
    }
  }

  Future<String> carregarObservacaoLocal() async {
    await _gravacoesPendentes;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cartKey);
    if (raw == null) return '';
    try {
      final decoded = json.decode(raw);
      return decoded is Map ? (decoded['observacao'] as String? ?? '') : '';
    } catch (_) {
      return '';
    }
  }

  /// O recibo e a subtração são persistidos na mesma gravação. Replays não
  /// removem outra vez unidades adicionadas após a recuperação original.
  Future<void> consumirPedido(String pedidoId, Map<String, dynamic> pedido) =>
      _gravar(() async {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_cartKey);
        if (raw == null) return;
        final decoded = jsonDecode(raw);
        final payload = decoded is List
            ? <String, dynamic>{'itens': decoded}
            : Map<String, dynamic>.from(decoded as Map);
        final consumed = List<String>.from(
          payload['pedidosConsumidos'] as List? ?? [],
        );
        if (consumed.contains(pedidoId)) return;
        final quantities = <String, int>{};
        for (final item in pedido['itens'] as List? ?? []) {
          final id = item['produtoId'] as String;
          quantities[id] =
              (quantities[id] ?? 0) + (item['quantidade'] as num).toInt();
        }
        final items = (payload['itens'] as List)
            .map(
              (item) =>
                  CartItemModel.fromMap(Map<String, dynamic>.from(item as Map)),
            )
            .toList();
        for (final item in items) {
          if (item.lojaId == pedido['lojaId'])
            item.quantidade -= quantities[item.produtoId] ?? 0;
        }
        items.removeWhere((item) => item.quantidade <= 0);
        payload['itens'] = items.map((item) => item.toMap()).toList();
        payload['pedidosConsumidos'] = [...consumed, pedidoId];
        if (items.isEmpty) payload['observacao'] = '';
        if (!await prefs.setString(_cartKey, jsonEncode(payload)))
          throw StateError('Não foi possível atualizar o carrinho.');
      });

  Future<void> limparCarrinho() => _gravar(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cartKey);
  });
}
