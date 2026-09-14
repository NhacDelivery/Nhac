import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalCacheService {
  static const String _keyUsuario = 'cache_usuario';
  static const String _keyEnderecos = 'cache_enderecos';
  static const String _keyLocalizacaoGps = 'cache_localizacao_gps';
  static const String _keySearchHistory = 'cache_search_history';

  static Future<void> salvarHistoricoPesquisa(List<String> historico) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keySearchHistory, historico);
    } catch (e) {
      debugPrint('LocalCacheService: erro ao salvar histórico — $e');
    }
  }

  static Future<List<String>> carregarHistoricoPesquisa() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_keySearchHistory) ?? [];
    } catch (e) {
      debugPrint('LocalCacheService: erro ao carregar histórico — $e');
      return [];
    }
  }

  static Future<void> salvarUsuario(Map<String, dynamic> dados) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUsuario, jsonEncode(dados));
    } catch (e) {
      debugPrint('LocalCacheService: erro ao salvar usuário — $e');
    }
  }

  static Future<Map<String, dynamic>?> carregarUsuario() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyUsuario);
      if (raw == null) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('LocalCacheService: erro ao carregar usuário — $e');
      return null;
    }
  }

  static Future<void> limparUsuario() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyUsuario);
    } catch (e) {
      debugPrint('LocalCacheService: erro ao limpar usuário — $e');
    }
  }


  static Future<void> salvarEnderecos(List<Map<String, dynamic>> lista) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyEnderecos, jsonEncode(lista));
    } catch (e) {
      debugPrint('LocalCacheService: erro ao salvar endereços — $e');
    }
  }

  static Future<List<Map<String, dynamic>>?> carregarEnderecos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyEnderecos);
      if (raw == null) return null;
      final lista = jsonDecode(raw) as List<dynamic>;
      return lista.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('LocalCacheService: erro ao carregar endereços — $e');
      return null;
    }
  }

  static Future<void> limparEnderecos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyEnderecos);
    } catch (e) {
      debugPrint('LocalCacheService: erro ao limpar endereços — $e');
    }
  }


  static Future<void> salvarLocalizacaoGps(String endereco) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLocalizacaoGps, endereco);
    } catch (e) {
      debugPrint('LocalCacheService: erro ao salvar GPS — $e');
    }
  }

  static Future<String?> carregarLocalizacaoGps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyLocalizacaoGps);
    } catch (e) {
      debugPrint('LocalCacheService: erro ao carregar GPS — $e');
      return null;
    }
  }

  // Cache em memória para a Home (produtos e lojas)
  // Limpo quando o app fecha (já que é memória) ou quando o usuário dá pull-to-refresh
  static List<dynamic>? produtosNecessidadesCache;
  static List<dynamic>? produtosPromocaoCache;
  
  static List<dynamic>? lojasCache;
  static int currentPageLojasCache = 0;
  static bool hasMoreLojasCache = true;

  static void limparCacheHome() {
    produtosNecessidadesCache = null;
    produtosPromocaoCache = null;
    lojasCache = null;
    currentPageLojasCache = 0;
    hasMoreLojasCache = true;
  }



  static Future<void> limparTudo() async {
    await Future.wait([
      limparUsuario(),
      limparEnderecos(),
    ]);
  }
}
