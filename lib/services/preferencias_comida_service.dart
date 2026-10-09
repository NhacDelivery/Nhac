import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:nhac/services/api_client.dart';
import 'package:nhac/services/local_cache_service.dart';

class PreferenciasComidaService {
  static String _pendente(String uid) => 'preferencias_comida_sync_$uid';
  static Future<Set<String>> carregar(String uid) async {
    final local = await LocalCacheService.carregarPreferenciasComida(uid);
    final prefs = await SharedPreferences.getInstance();
    final tentativa = prefs.getString(_pendente(uid));
    if (tentativa != null) {
      final valores = List<String>.from(jsonDecode(tentativa) as List).toSet();
      await LocalCacheService.salvarPreferenciasComida(uid, valores);
      await sincronizar(uid, valores);
      return valores;
    }
    final response = await ApiClient().dio.get(
          '/usuarios/$uid/preferencias-comida',
        );
    final salvas = response.data['preferencias'] as List?;
    if (salvas == null) {
      await sincronizar(uid, local);
      return local;
    }
    final escolhas = salvas.cast<String>().toSet();
    await LocalCacheService.salvarPreferenciasComida(uid, escolhas);
    return escolhas;
  }

  static Future<void> salvar(String uid, Set<String> valores) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
        _pendente(uid), jsonEncode(valores.toList()..sort()))) {
      throw StateError('Falha ao guardar a sincronização.');
    }
    await LocalCacheService.salvarPreferenciasComida(uid, valores);
    await sincronizar(uid, valores);
  }

  static Future<void> sincronizar(String uid, Set<String> valores) async {
    await ApiClient().dio.put(
      '/usuarios/$uid/preferencias-comida',
      data: {'preferencias': valores.toList()..sort()},
    );
    await (await SharedPreferences.getInstance()).remove(_pendente(uid));
  }
}
