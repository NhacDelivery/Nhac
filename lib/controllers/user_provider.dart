import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:nhac/globals/router.dart';
import 'package:nhac/models/usuario/usuario_model.dart';
import 'package:nhac/repositories/user_repository.dart';
import 'package:nhac/services/auth_service.dart';

class UserProvider with ChangeNotifier {
  final AuthService _authService;
  final UserRepository _userRepository;

  UserProvider({AuthService? authService, UserRepository? repository})
      : _authService = authService ?? authServiceRoteador,
        _userRepository = repository ?? UserRepository() {
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
    _usuario = null;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _authService.removeListener(_onSessionChanged);
    super.dispose();
  }

  UsuarioModel? _usuario;
  bool _isLoading = false;

  UsuarioModel? get usuario => _usuario;
  bool get isLoading => _isLoading;

  
  bool get isGoogleUser => _authService.isGoogleUser;
  bool get isPhoneUser => _authService.isPhoneUser;
  bool get hasPassword => _authService.hasPassword;

  Future<void> carregarDadosUsuario() async {
    final usuarioId = _authService.usuarioId;
    if (usuarioId == null) return;

    final sessionVersion = _sessionVersion;
    try {
      _isLoading = true;
      notifyListeners();

      final resultado = await _userRepository.buscarUsuario(usuarioId);
      if (_disposed || sessionVersion != _sessionVersion) return;
      _usuario = resultado;
    } catch (e) {
      debugPrint("Erro ao carregar dados do utilizador: $e");
    } finally {
      if (!_disposed && sessionVersion == _sessionVersion) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> atualizarFotoPerfil(File imagem) async {
    final usuarioId = _authService.usuarioId;

    if (usuarioId == null) {
      throw Exception("Utilizador não autenticado no Provider.");
    }

    try {
      _isLoading = true;
      notifyListeners();

      // Upload para Firebase Storage (mesmo padrão de editar_foto_page.dart).
      // O login do app usa JWT próprio da API, mas o Firebase Storage depende
      // de uma sessão do Firebase Auth para as Security Rules. Login anônimo
      // resolve sem exigir conta Firebase do utilizador.
      final storage = FirebaseStorage.instanceFor(app: Firebase.app());

      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }

      final ref = storage
          .ref()
          .child('usuarios_fotos')
          .child(usuarioId)
          .child('perfil.jpg');

      await ref.putFile(
        imagem,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final url = await ref.getDownloadURL();

      // Persiste a URL da imagem no backend via PUT /usuarios/{id}
      await _userRepository.atualizarDadosUsuario(usuarioId, {
        'imagemUrl': url,
      });

      await carregarDadosUsuario();
    } catch (e) {
      debugPrint("Erro ao atualizar foto de perfil: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void limparUsuario() {
    _usuario = null;
    notifyListeners();
  }
}

