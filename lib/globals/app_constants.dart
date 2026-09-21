import 'package:nowa_runtime/nowa_runtime.dart';

@NowaGenerated()
class AppConstants {
  // Base URL da API REST
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://backend-nhac.onrender.com/api/v1',
  );

  static const bool e2eMode =
      bool.fromEnvironment('E2E_MODE', defaultValue: false);

  static const String stripePublishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

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
}
