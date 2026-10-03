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

  Future<void> salvarCarrinhoLocal(List<CartItemModel> itens,
      {String observacao = ''}) {
    final jsonString = json.encode({
      'itens': itens.map((i) => i.toMap()).toList(),
      'observacao': itens.isEmpty ? '' : observacao,
    });
    return _gravar(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cartKey, jsonString);
    });
  }

  Future<List<CartItemModel>> carregarCarrinhoLocal() async {
    await _gravacoesPendentes;
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_cartKey);

      if (jsonString != null && jsonString.isNotEmpty) {
        final decoded = json.decode(jsonString);
        final List<dynamic> decodedList =
            decoded is List ? decoded : decoded['itens'];
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

  Future<void> limparCarrinho() => _gravar(() async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_cartKey);
      });
}
