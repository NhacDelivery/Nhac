import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

class BiometricService {
  static final _auth = LocalAuthentication();

  static Future<bool> isDeviceSecure() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (e) {
      debugPrint('Erro ao verificar suporte do dispositivo: $e');
      return false;
    }
  }

  static Future<bool> authenticate() async {
    try {
      final secure = await isDeviceSecure();

      if (!secure) {
        return false;
      }

      return await _auth.authenticate(
        localizedReason:
            'Autenticação necessária para acessar seus dados pessoais.',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Autenticação necessária',
            biometricHint: 'Toque no sensor',
          ),
        ],
      );
    } catch (e) {
      debugPrint('Erro na autenticação: $e');
      return false;
    }
  }
}
