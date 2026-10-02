import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nhac/models/pedido_model.dart';
import 'package:nhac/models/produto/produtos.dart';
import 'package:nhac/models/loja/lojas.dart';

class LocalCacheService {
  static const String _keyUsuario = 'cache_usuario';
  static const String _keyEnderecos = 'cache_enderecos';
  static const String _keyLocalizacaoGps = 'cache_localizacao_gps';
  static const String _keySearchHistory = 'cache_search_history';
  static const String _keyEmailVerificacao = 'email_verificacao_pendente';

  static Future<void> salvarEmailVerificacao(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEmailVerificacao, email.trim());
  }

  static Future<String?> carregarEmailVerificacao() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyEmailVerificacao);
  }

  static Future<void> limparEmailVerificacao() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyEmailVerificacao);
  }

  static String _keyPedidoAtivo(String usuarioId) => 'pedido_ativo_$usuarioId';
  static String _keySnapshotPedido(String usuarioId) => 'pedido_snapshot_$usuarioId';
  static const Duration retencaoHome = Duration(minutes: 15);
  static const String _keyCatalogoHome = 'catalogo_home_v1';

  static Future<void> salvarCatalogoHome() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCatalogoHome, jsonEncode({
      'salvoEm': DateTime.now().toUtc().toIso8601String(),
      'necessidades': produtosNecessidadesCache?.cast<ProdutosModel>().map((p) => p.toMap()).toList() ?? [],
      'promocoes': produtosPromocaoCache?.cast<ProdutosModel>().map((p) => p.toMap()).toList() ?? [],
      'lojas': lojasCache?.cast<LojasModel>().map((l) => l.toMap()).toList() ?? [],
      'paginaLojas': currentPageLojasCache,
      'maisLojas': hasMoreLojasCache,
    }));
  }

  static Future<void> restaurarCatalogoHome() async {
    if (ultimaAtualizacaoHome != null) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyCatalogoHome);
    if (raw == null) return;
    try {
      final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final salvoEm = DateTime.parse(data['salvoEm'] as String);
      if (DateTime.now().difference(salvoEm) > retencaoHome) {
        await prefs.remove(_keyCatalogoHome);
        return;
      }
      produtosNecessidadesCache = (data['necessidades'] as List)
          .map((p) => ProdutosModel.fromMap(Map<String, dynamic>.from(p as Map))).toList();
      produtosPromocaoCache = (data['promocoes'] as List)
          .map((p) => ProdutosModel.fromMap(Map<String, dynamic>.from(p as Map))).toList();
      lojasCache = (data['lojas'] as List)
          .map((l) => LojasModel.fromMap(Map<String, dynamic>.from(l as Map))).toList();
      currentPageLojasCache = (data['paginaLojas'] as num).toInt();
      hasMoreLojasCache = data['maisLojas'] == true;
      ultimaAtualizacaoHome = salvoEm;
    } catch (_) {
      await prefs.remove(_keyCatalogoHome);
    }
  }

  static Future<void> salvarSnapshotPedido(String usuarioId, PedidoModel pedido) async {
    final prefs = await SharedPreferences.getInstance();
    final map = pedido.toMap()..remove('codigoEntrega');
    await prefs.setString(_keySnapshotPedido(usuarioId), jsonEncode({
      'salvoEm': DateTime.now().toUtc().toIso8601String(),
      'pedido': map,
    }));
  }

  static Future<PedidoModel?> carregarSnapshotPedido(String usuarioId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keySnapshotPedido(usuarioId));
    if (raw == null) return null;
    try {
      final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final salvoEm = DateTime.parse(data['salvoEm'] as String);
      if (DateTime.now().difference(salvoEm) > retencaoHome) {
        await prefs.remove(_keySnapshotPedido(usuarioId));
        return null;
      }
      final pedido = PedidoModel.fromMap(Map<String, dynamic>.from(data['pedido'] as Map));
      return pedido.usuarioId == usuarioId && !pedido.status.terminal ? pedido : null;
    } catch (_) {
      await prefs.remove(_keySnapshotPedido(usuarioId));
      return null;
    }
  }

  static Future<void> removerSnapshotPedido(String usuarioId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySnapshotPedido(usuarioId));
  }

  static Future<String?> carregarPedidoAtivo(String usuarioId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPedidoAtivo(usuarioId));
  }

  static Future<void> salvarPedidoAtivo(String usuarioId, String pedidoId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPedidoAtivo(usuarioId), pedidoId);
  }

  static Future<void> removerPedidoAtivo(String usuarioId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPedidoAtivo(usuarioId));
  }

  static String _keyPedidoEntregueVisto(String pedidoId) => 'pedido_entregue_visto_$pedidoId';

  static Future<bool> isPedidoEntregueVisto(String pedidoId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyPedidoEntregueVisto(pedidoId)) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> marcarPedidoEntregueVisto(String pedidoId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyPedidoEntregueVisto(pedidoId), true);
    } catch (_) {}
  }

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
  // Restaurado do armazenamento local por até 15 minutos após fechar o app.
  static List<dynamic>? produtosNecessidadesCache;
  static List<dynamic>? produtosPromocaoCache;
  static DateTime? ultimaAtualizacaoHome;
  static bool get cacheHomeVencido => ultimaAtualizacaoHome == null ||
      DateTime.now().difference(ultimaAtualizacaoHome!) > const Duration(minutes: 2);
  
  static List<dynamic>? lojasCache;
  static int currentPageLojasCache = 0;
  static bool hasMoreLojasCache = true;

  static void limparCacheHome() {
    ultimaAtualizacaoHome = null;
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
      limparHistoricoPesquisa(),
      limparCatalogoHomePersistido(),
    ]);
  }

  static Future<void> limparHistoricoPesquisa() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySearchHistory);
  }

  static Future<void> limparCatalogoHomePersistido() async {
    limparCacheHome();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCatalogoHome);
  }

  /// Cache para resultados de busca (stale-while-revalidate)
  static const String _keySearchResults = 'cache_search_results_v1';
  static const Duration retencaoBusca = Duration(minutes: 10);

  static Future<void> salvarResultadosBusca(String termo, {
    required List<ProdutosModel> produtos,
    required List<LojasModel> lojas,
    required Map<String, bool> lojaAberta,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keySearchResults, jsonEncode({
        'termo': termo.toLowerCase().trim(),
        'salvoEm': DateTime.now().toUtc().toIso8601String(),
        'produtos': produtos.map((p) => p.toMap()).toList(),
        'lojas': lojas.map((l) => l.toMap()).toList(),
        'lojaAberta': lojaAberta,
      }));
    } catch (e) {
      debugPrint('LocalCacheService: erro ao salvar resultados de busca — $e');
    }
  }

  static Future<Map<String, dynamic>?> carregarResultadosBusca(String termo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keySearchResults);
      if (raw == null) return null;
      final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final termoSalvo = data['termo'] as String;
      final termoBusca = termo.toLowerCase().trim();
      if (termoSalvo != termoBusca) return null;
      final salvoEm = DateTime.parse(data['salvoEm'] as String);
      if (DateTime.now().difference(salvoEm) > retencaoBusca) {
        await prefs.remove(_keySearchResults);
        return null;
      }
      return data;
    } catch (e) {
      debugPrint('LocalCacheService: erro ao carregar resultados de busca — $e');
      return null;
    }
  }

  static Future<void> limparResultadosBusca() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keySearchResults);
    } catch (e) {
      debugPrint('LocalCacheService: erro ao limpar resultados de busca — $e');
    }
  }
}
