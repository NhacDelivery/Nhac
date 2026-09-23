import 'package:nowa_runtime/nowa_runtime.dart';

@NowaGenerated()
class AppConstants {
  // Base URL da API REST
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://backend-nhac.onrender.com/api/v1',
  );

  static const bool e2eMode = bool.fromEnvironment(
    'E2E_MODE',
    defaultValue: false,
  );

  static const String _e2eLatitude = String.fromEnvironment(
    'E2E_LATITUDE',
    defaultValue: '-23.550520',
  );
  static const String _e2eLongitude = String.fromEnvironment(
    'E2E_LONGITUDE',
    defaultValue: '-46.633308',
  );

  static double get e2eLatitude => double.parse(_e2eLatitude);
  static double get e2eLongitude => double.parse(_e2eLongitude);

  static const String stripePublishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  static bool get stripeConfigurado =>
      (stripePublishableKey.startsWith('pk_test_') ||
          stripePublishableKey.startsWith('pk_live_')) &&
      stripePublishableKey.length >= 30;

  static const String sentryDsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: '',
  );

  static const String googleApiKey = String.fromEnvironment(
    'GOOGLE_API_KEY',
    defaultValue: '',
  );

  static const String googlePlacesApiKey = String.fromEnvironment(
    'GOOGLE_PLACES_API_KEY',
    defaultValue: googleApiKey,
  );

  // Chaves de cache local (SharedPreferences)
  static const String cacheKeyCarrinho = '@nhac_cart_items';
  static const String cacheKeyUsuario = 'cache_usuario';
  static const String cacheKeyEnderecos = 'cache_enderecos';
  static const String cacheKeyLocalizacaoGps = 'cache_localizacao_gps';
  static const String cacheKeySearchHistory = 'cache_search_history';

  // Chaves para FlutterSecureStorage
  static const String secureKeyToken = 'secure_token';
  static const String secureKeyUsuarioId = 'secure_usuario_id';
  static const String secureKeyNomeUsuario = 'secure_nome_usuario';
  static const String secureKeyLoginGoogle = 'secure_login_google';
  static const String secureKeyLoginTelefone = 'secure_login_telefone';

  static void validateE2EConfiguration() {
    if (!e2eMode) {
      throw StateError('E2E_MODE=true é obrigatório para o bootstrap E2E.');
    }
    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw StateError(
        'API_BASE_URL deve apontar explicitamente para o backend E2E.',
      );
    }
    final host = uri.host.toLowerCase();
    const hostsE2EPermitidos = {'10.0.2.2', '127.0.0.1', 'localhost'};
    if (uri.scheme != 'http' || !hostsE2EPermitidos.contains(host)) {
      throw StateError(
        'E2E_MODE aceita somente backend HTTP isolado local; host recusado: $host.',
      );
    }
  }
}
