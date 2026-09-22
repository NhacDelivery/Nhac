import 'package:flutter/material.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:nhac/models/usuario/carrinho_model.dart';
import 'package:nhac/repositories/cart_repository.dart';

class CartProvider extends ChangeNotifier {
  final CartRepository? _repositoryOverride;
  final AuthService? _authService;
  String? _sessionUserId;
  int _sessionVersion = 0;
  bool _disposed = false;

  CartRepository get _cartRepository => _repositoryOverride ??
      CartRepository(usuarioId: _sessionUserId);

  CartProvider({CartRepository? repository, AuthService? authService})
      : _repositoryOverride = repository, _authService = authService {
    _sessionUserId = authService?.usuarioId;
    authService?.addListener(_onSessionChanged);
  }

  void _onSessionChanged() {
    if (_sessionUserId == _authService?.usuarioId) return;
    _sessionUserId = _authService?.usuarioId;
    _sessionVersion++;
    _itens = {};
    _observacao = '';
    _lojaIdAtual = '';
    _recalcularTotais();
  }

  @override
  void dispose() {
    _disposed = true;
    _authService?.removeListener(_onSessionChanged);
    super.dispose();
  }

  Map<String, CartItemModel> _itens = {};
  double _valorTotal = 0.0;
  int _totalDeUnidades = 0;
  String _observacao = '';
  String _lojaIdAtual = '';   

  Map<String, CartItemModel> get itens => _itens;
  int get quantidadeItens => _itens.length;
  double get valorTotal => _valorTotal;
  int get totalDeUnidades => _totalDeUnidades;
  String get observacao => _observacao;
  String get lojaId => _lojaIdAtual;   

  Future<void> carregarCarrinhoLocal() async {
    final sessionVersion = _sessionVersion;
    final listaSalva = await _cartRepository.carregarCarrinhoLocal();
    if (_disposed || sessionVersion != _sessionVersion) return;
    _itens = {for (var item in listaSalva) item.produtoId: item};
    _lojaIdAtual = '';
    if (_itens.isNotEmpty) {
      _lojaIdAtual = _itens.values.first.lojaId;  
    }
    _recalcularTotais();
  }

  void setObservacao(String texto) {
    if (_observacao != texto) {
      _observacao = texto;
      notifyListeners();
    }
  }

  Future<bool> adicionarItemComQuantidade({
    required String idProduto,
    required String nome,
    required double preco,
    required String imagemUrl,
    required String lojaId,    
    required int quantidade,
  }) async {
    if (quantidade <= 0) throw Exception('Quantidade inválida');

    if (_itens.isNotEmpty && _lojaIdAtual.isNotEmpty && _lojaIdAtual != lojaId) {
      throw Exception('Você só pode adicionar itens de uma loja por vez. Limpe o carrinho atual.');
    }

    if (_itens.containsKey(idProduto)) {
      _itens[idProduto]!.quantidade += quantidade;
    } else {
      _itens[idProduto] = CartItemModel(
        produtoId: idProduto,
        nome: nome,
        imagemUrl: imagemUrl,
        preco: preco,
        lojaId: lojaId,   
        quantidade: quantidade,
      );
    }

    _lojaIdAtual = lojaId;   
    _recalcularTotais();
    await _cartRepository.salvarCarrinhoLocal(_itens.values.toList());
    return true;   
  }

  Future<void> removerItem(String idProduto) async {
    if (!_itens.containsKey(idProduto)) return;

    if (_itens[idProduto]!.quantidade > 1) {
      _itens[idProduto]!.quantidade -= 1;
    } else {
      _itens.remove(idProduto);
    }

    if (_itens.isEmpty) _lojaIdAtual = '';   

    _recalcularTotais();
    await _cartRepository.salvarCarrinhoLocal(_itens.values.toList());
  }

  Future<void> excluirItemDoCarrinho(String idProduto) async {
    _itens.remove(idProduto);
    if (_itens.isEmpty) _lojaIdAtual = '';   
    _recalcularTotais();
    await _cartRepository.salvarCarrinhoLocal(_itens.values.toList());
  }

  void marcarItemComoEsgotado(String idProduto) {
    if (_itens.containsKey(idProduto)) {
      _itens[idProduto]!.esgotado = true;
      notifyListeners();
      _cartRepository.salvarCarrinhoLocal(_itens.values.toList());
    }
  }

  Future<void> esvaziarCarrinho() async {
    _itens.clear();
    _observacao = '';
    _lojaIdAtual = '';   
    _recalcularTotais();
    await _cartRepository.limparCarrinho();
  }

  void _recalcularTotais() {
    _valorTotal = 0.0;
    _totalDeUnidades = 0;
    _itens.forEach((key, item) {
      _valorTotal += item.preco * item.quantidade;
      _totalDeUnidades += item.quantidade;
    });
    notifyListeners();
  }
}
