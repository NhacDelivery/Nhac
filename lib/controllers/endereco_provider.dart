import 'package:flutter/material.dart';
import 'package:nhac/globals/router.dart';
import 'package:nhac/models/usuario/endereco_model.dart';
import 'package:nhac/repositories/endereco_repository.dart';
import 'package:nhac/services/auth_service.dart';

class EnderecoProvider with ChangeNotifier {
  final EnderecoRepository _enderecoRepository;
  final AuthService _authService;

  EnderecoProvider({AuthService? authService, EnderecoRepository? repository})
      : _authService = authService ?? authServiceRoteador,
        _enderecoRepository = repository ?? EnderecoRepository() {
    _sessionUserId = _authService.usuarioId;
    _authService.addListener(_onSessionChanged);
  }

  String? _sessionUserId;
  int _sessionVersion = 0;
  bool _disposed = false;

  void _onSessionChanged() {
    if (_sessionUserId == _authService.usuarioId) return;
    _sessionUserId = _authService.usuarioId;
    _sessionVersion++;
    _enderecos = [];
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _authService.removeListener(_onSessionChanged);
    super.dispose();
  }

  List<EnderecoModel> _enderecos = [];
  bool _isLoading = false;

  List<EnderecoModel> get enderecos => _enderecos;
  bool get isLoading => _isLoading;

  Future<void> buscarEnderecos() async {
    final usuarioId = _authService.usuarioId;
    if (usuarioId == null) return;

    final sessionVersion = _sessionVersion;
    try {
      _isLoading = true;
      notifyListeners();

      final resultado = await _enderecoRepository.buscarEnderecos(usuarioId);
      if (_disposed || sessionVersion != _sessionVersion) return;
      _enderecos = resultado;
    } catch (e) {
      debugPrint("Erro ao buscar endereços: $e");
    } finally {
      if (!_disposed && sessionVersion == _sessionVersion) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> adicionarEndereco(EnderecoModel endereco) async {
    final usuarioId = _authService.usuarioId;
    if (usuarioId == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      await _enderecoRepository.adicionarEndereco(usuarioId, endereco);
      await buscarEnderecos();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint("Erro ao adicionar endereço: $e");
      rethrow;
    }
  }

  Future<void> removerEndereco(String enderecoId) async {
    final usuarioId = _authService.usuarioId;
    if (usuarioId == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      await _enderecoRepository.removerEndereco(usuarioId, enderecoId);
      await buscarEnderecos();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint("Erro ao remover endereço: $e");
      rethrow;
    }
  }

  Future<void> atualizarEndereco(String enderecoId, EnderecoModel endereco) async {
    final usuarioId = _authService.usuarioId;
    if (usuarioId == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      await _enderecoRepository.atualizarEndereco(usuarioId, enderecoId, endereco);
      await buscarEnderecos();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint("Erro ao atualizar endereço: $e");
      rethrow;
    }
  }

  Future<void> definirComoPadrao(String enderecoId) async {
    final usuarioId = _authService.usuarioId;
    if (usuarioId == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      final enderecoSelecionado = _enderecos.firstWhere((e) => e.id == enderecoId);
      final enderecoPadraoAtual = _enderecos.cast<EnderecoModel?>().firstWhere((e) => e?.isPadrao == true && e?.id != enderecoId, orElse: () => null);

      if (enderecoPadraoAtual != null) {
        await _enderecoRepository.atualizarEndereco(
          usuarioId,
          enderecoPadraoAtual.id,
          enderecoPadraoAtual.copyWith(isPadrao: false),
        );
      }

      await _enderecoRepository.atualizarEndereco(
        usuarioId,
        enderecoId,
        enderecoSelecionado.copyWith(isPadrao: true),
      );

      await buscarEnderecos();
    } catch (e) {
      debugPrint("Erro ao definir como padrão: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
