import 'package:dio/dio.dart';
import 'package:nhac/repositories/cart_repository.dart';
import 'package:nhac/services/local_cache_service.dart';
import 'package:flutter/foundation.dart';
import 'package:nhac/globals/exceptions.dart';
import 'package:nhac/services/api_client.dart';
import 'package:nhac/services/session_storage_service.dart';
import 'package:uuid/uuid.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService with ChangeNotifier {
  final _dio = ApiClient().dio;
  final _sessionStorage = SessionStorageService();

  Future<void>? _logoutPendente;
  int _sessionGeneration = 0;
  String? _usuarioId;
  String? _nome;
  bool _carregado = false; 
  bool _isGoogleUser = false;
  bool _isPhoneUser = false;

  bool get isAuthenticated => _usuarioId != null;
  bool get carregado => _carregado;
  String? get usuarioId => _usuarioId;
  String? get nome => _nome;

  AuthService() {
    _carregarSessaoLocal();
  }

  Future<void> _carregarSessaoLocal() async {
    final generation = _sessionGeneration;
    final usuarioId = await _sessionStorage.obterUsuarioId();
    final nome = await _sessionStorage.obterNome();
    final google = await _sessionStorage.obterLoginGoogle();
    final telefone = await _sessionStorage.obterLoginTelefone();
    if (generation != _sessionGeneration) return;
    _usuarioId = usuarioId;
    _nome = nome;
    _isGoogleUser = google;
    _isPhoneUser = telefone;
    _carregado = true;
    notifyListeners();
  }

  Future<void> login({required String email, required String senha}) async {
    try {
      final response = await _dio.post('/auth/login', data: {'email': email, 'senha': senha});
      await _salvarSessaoDaResposta(response.data);
    } catch (e) {
     
      throw mapException(e);
    }
  }

  Future<void> registrar({
    required String nome,
    required String email,
    required String telefone,
    required String senha,
  }) async {
    try {
      final id = const Uuid().v4();
      final response = await _dio.post('/auth/registrar', data: {
        'id': id, 'nome': nome, 'email': email, 'telefone': telefone, 'senha': senha,
      });
      await _salvarSessaoDaResposta(response.data);
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<bool> checarEmail(String email) async {
    try {
      final response = await _dio.post('/auth/checar-email', data: {
        'email': email.trim(),
      });
      return response.data['existe'] == true;
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<void> enviarCodigoCadastro(String email) async {
    try {
      await _dio.post('/auth/enviar-codigo-cadastro', data: {
        'email': email.trim(),
      });
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<void> confirmarEmailCadastro(String email, String codigo) async {
    try {
      await _dio.post('/auth/confirmar-email-cadastro', data: {
        'email': email.trim(),
        'codigo': codigo.trim(),
      });
    } catch (e) {
      throw mapException(e);
    }
  }

  String formatarTelefoneE164(String telefoneBR) {
    final numeros = telefoneBR.replaceAll(RegExp(r'\D'), '');
    return '+55$numeros';
  }

  Future<void> enviarCodigoSms(String telefone) async {
    try {
      await _dio.post('/verificacao-telefone/enviar-codigo', data: {
        'telefone': formatarTelefoneE164(telefone),
      });
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<bool> loginSms(String telefone, String codigo) async {
    try {
      final response = await _dio.post('/auth/login-sms', data: {
        'telefone': formatarTelefoneE164(telefone),
        'codigo': codigo,
      });
      await _salvarSessaoDaResposta(response.data, viaTelefone: true);
      return response.data['isNovoUsuario'] == true;
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<void> _salvarSessaoDaResposta(Map<String, dynamic> data, {bool viaGoogle = false, bool viaTelefone = false}) async {
    await _logoutPendente;
    final token = data['token'] as String;
    final usuarioId = data['usuarioId'] as String;
    final nome = data['nome'] as String;
    await _sessionStorage.salvarSessao(token: token, usuarioId: usuarioId, nome: nome);
    ApiClient().atualizarTokenCache(token);
    await _sessionStorage.salvarLoginGoogle(viaGoogle);
    await _sessionStorage.salvarLoginTelefone(viaTelefone);
    _usuarioId = usuarioId;
    _nome = nome;
    _isGoogleUser = viaGoogle;
    _isPhoneUser = viaTelefone;
    notifyListeners();
  }

  Future<void> logout() {
    return _logoutPendente ??= _encerrarSessao().whenComplete(() {
      _logoutPendente = null;
    });
  }

  Future<void> _encerrarSessao() async {
    final usuarioAnterior = _usuarioId;
    _sessionGeneration++;
    ApiClient().atualizarTokenCache(null);
    _usuarioId = null;
    _nome = null;
    _isGoogleUser = false;
    _isPhoneUser = false;
    _carregado = true;
    notifyListeners();
    // Os providers limpam a memória ao receber a mudança da sessão.
    // O mesmo caminho atende ao logout manual e à expiração por HTTP 401.
    await Future.wait([
      _sessionStorage.limparSessao(),
      CartRepository(usuarioId: usuarioAnterior).limparCarrinho(),
      CartRepository().limparCarrinho(),
      LocalCacheService.limparTudo(),
    ]);
  }

  Future<void> signOut() => logout();

  Future<void> esqueciSenhaEmail(String email, {CancelToken? cancelToken}) async {
    try {
      await _dio.post(
        '/auth/esqueci-senha/email', 
        data: {
          'email': email,
        },
        cancelToken: cancelToken,
      );
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<void> validarCodigoRecuperacaoEmail(String email, String codigo) async {
    try {
      await _dio.post('/auth/validar-codigo-redefinicao/email', data: {
        'email': email.trim(),
        'codigo': codigo.trim(),
      });
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<void> redefinirSenhaEmail(String email, String codigo, String novaSenha) async {
    try {
      await _dio.post('/auth/redefinir-senha/email', data: {
        'email': email,
        'codigo': codigo,
        'novaSenha': novaSenha,
      });
    } catch (e) {
      throw mapException(e);
    }
  }


  Future<void> alterarSenha(String senhaAtual, String novaSenha) async {
    if (_usuarioId == null) {
      throw AuthException('Utilizador não autenticado.');
    }
    try {
      await _dio.put('/auth/alterar-senha', data: {
        'senhaAtual': senhaAtual,
        'novaSenha': novaSenha,
      });
    } catch (e) {
      throw mapException(e);
    }
  }

Future<void> updateUserName({required String userName}) async {
  if (_usuarioId == null) {
    throw AuthException('Utilizador não autenticado.');
  }

  final nomeLimpo = userName.trim();

  try {
    final response = await _dio.put('/usuarios/$_usuarioId', data: {
      'nome': nomeLimpo 
    });

    final tokenFresquinho = response.data['token'] as String?;
    final tokenFinal = (tokenFresquinho != null && tokenFresquinho.isNotEmpty)
        ? tokenFresquinho
        : await _sessionStorage.obterToken();

    if (tokenFinal == null) {
      throw AuthException('Sessão inválida ao salvar novo nome.');
    }

    _nome = nomeLimpo;

    await _sessionStorage.salvarSessao(
      token: tokenFinal,
      usuarioId: _usuarioId!,
      nome: nomeLimpo,
    );
    
    ApiClient().atualizarTokenCache(tokenFinal);
  } catch (e) {
    throw mapException(e);
  }
}



  Future<void> updateEmail({required String novoEmail}) async {
    if (_usuarioId == null) {
      throw AuthException('Utilizador não autenticado.');
    }

    try {
      final response = await _dio.put('/usuarios/$_usuarioId', data: {
        'email': novoEmail.trim(),
      });

      final tokenFresquinho = response.data['token'] as String?;
      if (tokenFresquinho == null || tokenFresquinho.isEmpty) {
        throw AuthException('Backend não retornou um token válido.');
      }

      await _sessionStorage.salvarSessao(
        token: tokenFresquinho,
        usuarioId: _usuarioId!,
        nome: _nome ?? 'Usuário',
      );
      
      ApiClient().atualizarTokenCache(tokenFresquinho);
      notifyListeners();
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<void> updateFcmToken({required String fcmToken}) async {
    if (_usuarioId == null) {
      throw AuthException('Utilizador não autenticado.');
    }

    try {
      final response = await _dio.put('/usuarios/$_usuarioId', data: {
        'fcmToken': fcmToken.trim(),
      });
      final tokenFresquinho = response.data['token'] as String?;
      if (tokenFresquinho != null && tokenFresquinho.isNotEmpty) {
        await _sessionStorage.salvarSessao(
          token: tokenFresquinho,
          usuarioId: _usuarioId!,
          nome: _nome ?? 'Usuário',
        );
        ApiClient().atualizarTokenCache(tokenFresquinho);
        notifyListeners();
      }
    } catch (e) {
      throw mapException(e);
    }
  }

   Future<void> loginComGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      
      await googleSignIn.signOut();
      
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) return; 

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken != null) {
        final response = await _dio.post('/auth/social', data: {'idToken': idToken});
        
        await _salvarSessaoDaResposta(response.data, viaGoogle: true);
      } else {
        throw AuthException('Não foi possível obter o token de autenticação do Google.');
      }
    } catch (e) {
      throw mapException(e);
    }
  }

  
  bool get isGoogleUser => _isGoogleUser;
  bool get isPhoneUser => _isPhoneUser;
  bool get hasPassword => !_isGoogleUser && !_isPhoneUser;
}
