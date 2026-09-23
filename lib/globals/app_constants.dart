import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

@NowaGenerated()
class AppConstants {
  // ============================================================
  // API
  // ============================================================

  static String get apiBaseUrl {
    final value = dotenv.env['API_BASE_URL'];

    if (value == null || value.trim().isEmpty) {
      return 'https://backend-nhac.onrender.com/api/v1';
    }

    return value.trim();
  }

  // ============================================================
  // E2E
  // ============================================================

  static bool get e2eMode {
    return dotenv.env['E2E_MODE']?.trim().toLowerCase() == 'true';
  }

  static String get _e2eLatitude {
    return dotenv.env['E2E_LATITUDE']?.trim() ?? '-23.550520';
  }

  static String get _e2eLongitude {
    return dotenv.env['E2E_LONGITUDE']?.trim() ?? '-46.633308';
  }

  static double get e2eLatitude {
    return double.tryParse(_e2eLatitude) ?? -23.550520;
  }

  static double get e2eLongitude {
    return double.tryParse(_e2eLongitude) ?? -46.633308;
  }

  // ============================================================
  // STRIPE
  // ============================================================

  static String get stripePublishableKey {
    return dotenv.env['STRIPE_PUBLISHABLE_KEY']?.trim() ?? '';
  }

  static bool get stripeConfigurado {
    return (stripePublishableKey.startsWith('pk_test_') ||
            stripePublishableKey.startsWith('pk_live_')) &&
        stripePublishableKey.length >= 30;
  }

  // ============================================================
  // SENTRY
  // ============================================================

  static String get sentryDsn {
    return dotenv.env['SENTRY_DSN']?.trim() ?? '';
  }

  // ============================================================
  // GOOGLE
  // ============================================================

  static String get googleApiKey {
    return dotenv.env['GOOGLE_API_KEY']?.trim() ?? '';
  }

  static String get googlePlacesApiKey {
    final placesKey =
        dotenv.env['GOOGLE_PLACES_API_KEY']?.trim() ?? '';

    // Se não houver uma chave específica para Places,
    // utiliza GOOGLE_API_KEY.
    if (placesKey.isNotEmpty) {
      return placesKey;
    }

    return googleApiKey;
  }

  // ============================================================
  // CACHE LOCAL - SharedPreferences
  // ============================================================

  static const String cacheKeyCarrinho = '@nhac_cart_items';
  static const String cacheKeyUsuario = 'cache_usuario';
  static const String cacheKeyEnderecos = 'cache_enderecos';
  static const String cacheKeyLocalizacaoGps =
      'cache_localizacao_gps';
  static const String cacheKeySearchHistory =
      'cache_search_history';

  // ============================================================
  // FlutterSecureStorage
  // ============================================================

  static const String secureKeyToken = 'secure_token';
  static const String secureKeyUsuarioId = 'secure_usuario_id';
  static const String secureKeyNomeUsuario = 'secure_nome_usuario';
  static const String secureKeyLoginGoogle = 'secure_login_google';
  static const String secureKeyLoginTelefone =
      'secure_login_telefone';

  // ============================================================
  // Validação E2E
  // ============================================================

  static void validateE2EConfiguration() {
    if (!e2eMode) {
      throw StateError(
        'E2E_MODE=true é obrigatório para o bootstrap E2E.',
      );
    }

    final uri = Uri.tryParse(apiBaseUrl);

    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw StateError(
        'API_BASE_URL deve apontar explicitamente para o backend E2E.',
      );
    }

    final host = uri.host.toLowerCase();

    const hostsE2EPermitidos = {
      '10.0.2.2',
      '127.0.0.1',
      'localhost',
    };

    if (uri.scheme != 'http' ||
        !hostsE2EPermitidos.contains(host)) {
      throw StateError(
        'E2E_MODE aceita somente backend HTTP isolado local; '
        'host recusado: $host.',
      );
    }
  }
}