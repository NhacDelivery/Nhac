import 'package:flutter/material.dart';
import 'package:nhac/services/auth_service.dart';

class CadastroController extends ChangeNotifier {
  final AuthService? _authService;
  String? _sessionUserId;

  CadastroController({AuthService? authService}) : _authService = authService {
    _sessionUserId = authService?.usuarioId;
    authService?.addListener(_onSessionChanged);
  }

  void _onSessionChanged() {
    if (_sessionUserId == _authService?.usuarioId) return;
    _sessionUserId = _authService?.usuarioId;
    limparDados();
  }

  @override
  void dispose() {
    _authService?.removeListener(_onSessionChanged);
    super.dispose();
  }

  String _email = '';
  String _nome = '';
  String _telefone = '';
  String _verificationId = ''; 
  String _senha = ''; 

  String get email => _email;
  String get nome => _nome;
  String get telefone => _telefone;
  String get verificationId => _verificationId;
  String get senha => _senha; 

  void setNome(String novoNome) {
    _nome = novoNome;
    notifyListeners(); 
  }

  void setEmail(String novoEmail) {
    _email = novoEmail;
    notifyListeners();
  }

  void setSenha(String novaSenha) {
    _senha = novaSenha;
    notifyListeners();
  }

  void setTelefone(String novoTelefone) {
    _telefone = novoTelefone; 
    notifyListeners();
  }

  void setVerificationId(String value) {
    _verificationId = value;
    notifyListeners();
  }

  void limparDados() {
    _email = '';
    _nome = '';
    _telefone = '';
    _verificationId = '';
    _senha = '';
    notifyListeners();
  }
}
