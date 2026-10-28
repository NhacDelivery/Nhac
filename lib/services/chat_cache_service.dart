import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nhac/models/chat/mensagem_chat.dart';

/// Serviço de cache de conversas do chat.
///
/// Utiliza estratégia de cache em 2 níveis:
/// 1. Em memória (L1): Acesso síncrono instantâneo (0ms) para navegações frequentes.
/// 2. Em disco via SharedPreferences (L2): Persistência entre reinicializações do app.
class ChatCacheService {
  static final Map<String, List<MensagemChat>> _cacheMemoria = {};
  static final Map<String, String> _lojaParaConversaMemoria = {};
  static const int _limiteMaximoMensagens = 60;

  static String _chaveConversa(String conversaId) =>
      'cache_chat_mensagens_$conversaId';

  static String _chaveLoja(String lojaId) =>
      'cache_chat_loja_conversa_$lojaId';

  /// Retorna as mensagens em memória de forma síncrona imediata (se existirem).
  static List<MensagemChat>? obterMemoria(String conversaId) {
    final msgs = _cacheMemoria[conversaId];
    if (msgs != null && msgs.isNotEmpty) {
      return List.unmodifiable(msgs);
    }
    return null;
  }

  /// Retorna as mensagens em cache (busca na memória primeiro; se não houver, busca no disco).
  static Future<List<MensagemChat>?> carregarCache(String conversaId) async {
    final emMemoria = obterMemoria(conversaId);
    if (emMemoria != null) return emMemoria;

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_chaveConversa(conversaId));
      if (jsonStr == null || jsonStr.isEmpty) return null;

      final list = jsonDecode(jsonStr) as List<dynamic>;
      final mensagens = list
          .map((item) => MensagemChat.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList()
        ..sort((a, b) => a.enviadaEm.compareTo(b.enviadaEm));

      _cacheMemoria[conversaId] = List.from(mensagens);
      return List.unmodifiable(mensagens);
    } catch (_) {
      return null;
    }
  }

  /// Salva as mensagens no cache em memória e em disco.
  static Future<void> salvar(
    String conversaId,
    List<MensagemChat> mensagens,
  ) async {
    if (conversaId.isEmpty) return;

    // Garante ordenação e deduplicação
    final mapaDeduplicado = <String, MensagemChat>{};
    for (final m in mensagens) {
      mapaDeduplicado[m.id] = m;
    }
    final ordenadas = mapaDeduplicado.values.toList()
      ..sort((a, b) => a.enviadaEm.compareTo(b.enviadaEm));

    // Salva na memória
    _cacheMemoria[conversaId] = List.from(ordenadas);

    // Salva em disco (mantém até _limiteMaximoMensagens mensagens mais recentes)
    try {
      final inicio = ordenadas.length > _limiteMaximoMensagens
          ? ordenadas.length - _limiteMaximoMensagens
          : 0;
      final paraSalvar = ordenadas.sublist(inicio);
      final jsonList = paraSalvar.map((m) => m.toMap()).toList();
      final jsonStr = jsonEncode(jsonList);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chaveConversa(conversaId), jsonStr);
    } catch (_) {
      // Falha silenciosa para não quebrar o fluxo do chat
    }
  }

  /// Retorna o ID da conversa associado a uma loja em memória.
  static String? obterConversaIdPorLojaMemoria(String lojaId) {
    return _lojaParaConversaMemoria[lojaId];
  }

  /// Retorna o ID da conversa associado a uma loja (memória ou disco).
  static Future<String?> obterConversaIdPorLoja(String lojaId) async {
    final emMemoria = _lojaParaConversaMemoria[lojaId];
    if (emMemoria != null && emMemoria.isNotEmpty) return emMemoria;

    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_chaveLoja(lojaId));
      if (id != null && id.isNotEmpty) {
        _lojaParaConversaMemoria[lojaId] = id;
        return id;
      }
    } catch (_) {}
    return null;
  }

  /// Associa um ID de loja a um ID de conversa para abertura rápida.
  static Future<void> associarLojaConversa(
    String lojaId,
    String conversaId,
  ) async {
    if (lojaId.isEmpty || conversaId.isEmpty) return;
    _lojaParaConversaMemoria[lojaId] = conversaId;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chaveLoja(lojaId), conversaId);
    } catch (_) {}
  }

  static final Map<String, String> _lojaFotosMemoria = {};
  static String _chaveLojaFoto(String lojaId) => 'cache_chat_loja_foto_$lojaId';

  /// Obtém a URL da foto da loja em memória.
  static String? obterFotoLojaMemoria(String lojaId) => _lojaFotosMemoria[lojaId];

  /// Obtém a URL da foto da loja (memória ou disco).
  static Future<String?> obterFotoLoja(String lojaId) async {
    final emMemoria = _lojaFotosMemoria[lojaId];
    if (emMemoria != null && emMemoria.isNotEmpty) return emMemoria;
    try {
      final prefs = await SharedPreferences.getInstance();
      final url = prefs.getString(_chaveLojaFoto(lojaId));
      if (url != null && url.isNotEmpty) {
        _lojaFotosMemoria[lojaId] = url;
        return url;
      }
    } catch (_) {}
    return null;
  }

  /// Salva a URL da foto da loja em memória e disco.
  static Future<void> salvarFotoLoja(String lojaId, String fotoUrl) async {
    if (lojaId.isEmpty || fotoUrl.isEmpty) return;
    _lojaFotosMemoria[lojaId] = fotoUrl;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chaveLojaFoto(lojaId), fotoUrl);
    } catch (_) {}
  }

  /// Limpa o cache de uma conversa específica.
  static Future<void> limparCacheConversa(String conversaId) async {
    _cacheMemoria.remove(conversaId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_chaveConversa(conversaId));
    } catch (_) {}
  }
}
