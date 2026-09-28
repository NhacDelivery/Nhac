import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nhac/globals/app_constants.dart';

class SessionStorageService {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  Future<void> salvarSessao({
    required String token,
    required String usuarioId,
    required String nome,
  }) async {
    await _storage.write(key: AppConstants.secureKeyToken, value: token);
    await _storage.write(key: AppConstants.secureKeyUsuarioId, value: usuarioId);
    await _storage.write(key: AppConstants.secureKeyNomeUsuario, value: nome);
  }

  Future<String?> obterToken() async {
    return await _storage.read(key: AppConstants.secureKeyToken);
  }

  Future<String?> obterUsuarioId() async {
    return await _storage.read(key: AppConstants.secureKeyUsuarioId);
  }

  Future<String?> obterNome() async {
    return await _storage.read(key: AppConstants.secureKeyNomeUsuario);
  }

  // Guarda localmente se a sessão atual foi aberta via Google. O backend
  // não devolve nenhum campo indicando o provedor de login (nem no login
  // normal, nem no /auth/social), então isso é rastreado no próprio
  // dispositivo, no momento em que o login acontece.
  Future<void> salvarLoginGoogle(bool viaGoogle) async {
    await _storage.write(
      key: AppConstants.secureKeyLoginGoogle,
      value: viaGoogle.toString(),
    );
  }

  Future<bool> obterLoginGoogle() async {
    final valor = await _storage.read(key: AppConstants.secureKeyLoginGoogle);
    return valor == 'true';
  }

  Future<void> salvarLoginTelefone(bool viaTelefone) async {
    await _storage.write(
      key: AppConstants.secureKeyLoginTelefone,
      value: viaTelefone.toString(),
    );
  }

  Future<bool> obterLoginTelefone() async {
    final valor = await _storage.read(key: AppConstants.secureKeyLoginTelefone);
    return valor == 'true';
  }

  Future<void> limparSessao() async {
    await _storage.delete(key: AppConstants.secureKeyToken);
    await _storage.delete(key: AppConstants.secureKeyUsuarioId);
    await _storage.delete(key: AppConstants.secureKeyNomeUsuario);
    await _storage.delete(key: AppConstants.secureKeyLoginGoogle);
    await _storage.delete(key: AppConstants.secureKeyLoginTelefone);
  }
}
