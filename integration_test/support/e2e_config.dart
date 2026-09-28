import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:nhac/globals/app_constants.dart';

abstract final class E2EConfig {
  static const bool runE2E = bool.fromEnvironment(
    'RUN_E2E',
    defaultValue: false,
  );

  static const String email = 'e2e.cliente@nhac.local';
  static const String password = 'NhacE2E#123';
  static const String storeId = 'e2e-loja-001';
  static const String productId = 'e2e-produto-001';

  static Future<void> validate() async {
    if (!runE2E) {
      throw StateError('RUN_E2E=true é obrigatório para executar a suíte E2E.');
    }
    await dotenv.load(fileName: '.env');
    AppConstants.validateE2EConfiguration();
  }
}
