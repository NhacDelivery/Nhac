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
    _erro = null;
    _requestVersion++;
    _mutando = false;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _authService.removeListener(_onSessionChanged);
    super.dispose();
  }

  String? _erro;
  String? get erro => _erro;
  int _requestVersion = 0;
  bool _mutando = false;
  List<EnderecoModel> _enderecos = [];
  bool _isLoading = false;

  List<EnderecoModel> get enderecos => _enderecos;
  bool get isLoading => _isLoading || _mutando;

  bool _cadastrandoAutomatico = false;

  Future<void> adicionarEnderecoAutomatico(EnderecoModel endereco) async {
    if (_cadastrandoAutomatico || _mutando) return;
    final sessao = _sessionVersion;
    _cadastrandoAutomatico = true;
    try {
      final consulta = buscarEnderecos();
      final versaoConsulta = _requestVersion;
      await consulta;
      if (_disposed || sessao != _sessionVersion || versaoConsulta != _requestVersion || _isLoading || _erro != null ||
          _authService.usuarioId == null || _enderecos.isNotEmpty || _mutando) {
        return;
      }
      // GPS nunca substitui um padrão escolhido no servidor.
      await adicionarEndereco(endereco.copyWith(isPadrao: false));
    } finally {
      _cadastrandoAutomatico = false;
    }
  }

  Future<void> buscarEnderecos() async {
    final usuarioId = _authService.usuarioId;
    if (usuarioId == null) return;

    final sessionVersion = _sessionVersion;
    final requestVersion = ++_requestVersion;
    try {
      _isLoading = true;
      _erro = null;
      notifyListeners();

      final resultado = await _enderecoRepository.buscarEnderecos(usuarioId);
      if (_disposed ||
          sessionVersion != _sessionVersion ||
          requestVersion != _requestVersion) {
        return;
      }
      _enderecos = resultado;
    } catch (e) {
      if (!_disposed &&
          sessionVersion == _sessionVersion &&
          requestVersion == _requestVersion) {
        _erro = "Não foi possível atualizar os endereços. Tente novamente.";
      }
    } finally {
      if (!_disposed &&
          sessionVersion == _sessionVersion &&
          requestVersion == _requestVersion) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _alterarEndereco(Future<void> Function(String) operacao,
      {void Function()? aoConfirmar}) async {
    final usuarioId = _authService.usuarioId;
    if (usuarioId == null) {
      throw StateError('Faça login para alterar o endereço.');
    }
    if (_mutando) throw StateError('Aguarde a alteração do endereço.');
    final sessao = _sessionVersion;
    _mutando = true;
    _requestVersion++;
    _isLoading = true;
    _erro = null;
    notifyListeners();
    try {
      await operacao(usuarioId);
      if (_disposed || sessao != _sessionVersion) return;
      aoConfirmar?.call();
      await buscarEnderecos();
      if (!_disposed && sessao == _sessionVersion && _erro != null) {
        _erro =
            'Alteração salva, mas não foi possível atualizar a lista. Tente atualizar novamente.';
      }
    } finally {
      _mutando = false;
      if (!_disposed && sessao == _sessionVersion) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> adicionarEndereco(EnderecoModel endereco) =>
      _alterarEndereco((usuarioId) =>
          _enderecoRepository.adicionarEndereco(usuarioId, endereco));

  Future<void> removerEndereco(String enderecoId) => _alterarEndereco(
        (usuarioId) =>
            _enderecoRepository.removerEndereco(usuarioId, enderecoId),
        aoConfirmar: () => _enderecos.removeWhere((e) => e.id == enderecoId),
      );

  Future<void> atualizarEndereco(String enderecoId, EnderecoModel endereco) =>
      _alterarEndereco(
        (usuarioId) => _enderecoRepository.atualizarEndereco(
            usuarioId, enderecoId, endereco),
        aoConfirmar: () => _enderecos = _enderecos
            .map((e) => e.id == enderecoId
                ? endereco
                : endereco.isPadrao
                    ? e.copyWith(isPadrao: false)
                    : e)
            .toList(),
      );

  Future<void> definirComoPadrao(String enderecoId) async {
    final usuarioId = _authService.usuarioId;
    if (usuarioId == null) {
      throw StateError('Faça login para selecionar o endereço.');
    }
    if (_isLoading) throw StateError('Aguarde a atualização do endereço.');
    final sessionVersion = _sessionVersion;
    _requestVersion++;
    _isLoading = true;
    notifyListeners();
    try {
      final selecionado = _enderecos.firstWhere((e) => e.id == enderecoId);
      // O backend desmarca os demais na mesma transação desta atualização.
      await _enderecoRepository.atualizarEndereco(
        usuarioId,
        enderecoId,
        selecionado.copyWith(isPadrao: true),
      );
      if (_disposed || sessionVersion != _sessionVersion) {
        throw StateError('A sessão mudou. Selecione o endereço novamente.');
      }
      _enderecos = _enderecos
          .map((e) => e.copyWith(isPadrao: e.id == enderecoId))
          .toList();
    } finally {
      if (!_disposed && sessionVersion == _sessionVersion) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }
}
