import 'package:flutter/widgets.dart';
import 'package:nhac/globals/app_constants.dart';
import 'package:nhac/globals/router.dart';
import 'package:nhac/services/api_client.dart';
import 'package:nhac/services/local_cache_service.dart';
import 'package:nhac/services/session_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract final class E2EBootstrap {
  static Future<void> prepare() async {
    AppConstants.validateE2EConfiguration();
    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();
    LocalCacheService.limparCacheHome();
    await SessionStorageService().limparSessao();
    while (!authServiceRoteador.carregado) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await authServiceRoteador.logout();
    ApiClient().atualizarTokenCache(null);
  }

  static void runIsolated(Widget app) {
    runApp(app);
  }
}
