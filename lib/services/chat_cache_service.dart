import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nhac/models/chat/mensagem_chat.dart';
import 'package:nhac/models/chat/conversa_resumo.dart';
import 'package:nhac/models/chat/conversa_pessoa_resumo.dart';

/// Serviço de cache permanente de conversas e mensagens do chat.
///
/// Utiliza estratégia de cache em 2 níveis (L1 Memória + L2 SharedPreferences/Disco):
/// - Acesso síncrono instantâneo (0ms) na memória para navegações ativas.
/// - Persistência permanente em disco para carregamento 100% funcional offline.
class ChatCacheService {
  static final Map<String, List<MensagemChat>> _cacheMemoria = {};
  static final Map<String, String> _lojaParaConversaMemoria = {};
  static List<ConversaResumo>? _conversasLojasMemoria;
  static List<ConversaPessoaResumo>? _conversasPessoasMemoria;
  static const int _limiteMaximoMensagens = 250;

  static const String _chaveConversasLojas = 'cache_chat_conversas_lojas_v1';
  static const String _chaveConversasPessoas = 'cache_chat_conversas_pessoas_v1';

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

  /// Salva a lista de conversas com lojas em disco e memória.
  static Future<void> salvarConversasLojas(List<ConversaResumo> conversas) async {
    _conversasLojasMemoria = List.from(conversas);
    try {
      final jsonList = conversas.map((c) => c.toMap()).toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chaveConversasLojas, jsonEncode(jsonList));

      // Indexa lojas para abertura e fotos offline rápidas
      for (final c in conversas) {
        if (c.lojaId.isNotEmpty && c.id.isNotEmpty) {
          _lojaParaConversaMemoria[c.lojaId] = c.id;
          await prefs.setString(_chaveLoja(c.lojaId), c.id);
        }
        if (c.lojaId.isNotEmpty && (c.lojaFotoUrl?.isNotEmpty ?? false)) {
          _lojaFotosMemoria[c.lojaId] = c.lojaFotoUrl!;
          await prefs.setString(_chaveLojaFoto(c.lojaId), c.lojaFotoUrl!);
        }
      }
    } catch (_) {}
  }

  /// Carrega a lista de conversas com lojas (busca na memória e depois em disco).
  static Future<List<ConversaResumo>> carregarConversasLojas() async {
    if (_conversasLojasMemoria != null && _conversasLojasMemoria!.isNotEmpty) {
      return List.unmodifiable(_conversasLojasMemoria!);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_chaveConversasLojas);
      if (raw == null || raw.isEmpty) return const [];
      final list = jsonDecode(raw) as List<dynamic>;
      final conversas = list
          .map((item) => ConversaResumo.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
      _conversasLojasMemoria = List.from(conversas);

      // Restaura indexação offline
      for (final c in conversas) {
        if (c.lojaId.isNotEmpty && c.id.isNotEmpty) {
          _lojaParaConversaMemoria[c.lojaId] = c.id;
        }
        if (c.lojaId.isNotEmpty && (c.lojaFotoUrl?.isNotEmpty ?? false)) {
          _lojaFotosMemoria[c.lojaId] = c.lojaFotoUrl!;
        }
      }

      return List.unmodifiable(conversas);
    } catch (_) {
      return const [];
    }
  }

  /// Salva a lista de conversas com pessoas em disco e memória.
  static Future<void> salvarConversasPessoas(List<ConversaPessoaResumo> conversas) async {
    _conversasPessoasMemoria = List.from(conversas);
    try {
      final jsonList = conversas.map((c) => c.toMap()).toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chaveConversasPessoas, jsonEncode(jsonList));
    } catch (_) {}
  }

  /// Carrega a lista de conversas com pessoas (busca na memória e depois em disco).
  static Future<List<ConversaPessoaResumo>> carregarConversasPessoas() async {
    if (_conversasPessoasMemoria != null && _conversasPessoasMemoria!.isNotEmpty) {
      return List.unmodifiable(_conversasPessoasMemoria!);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_chaveConversasPessoas);
      if (raw == null || raw.isEmpty) return const [];
      final list = jsonDecode(raw) as List<dynamic>;
      final conversas = list
          .map((item) => ConversaPessoaResumo.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
      _conversasPessoasMemoria = List.from(conversas);
      return List.unmodifiable(conversas);
    } catch (_) {
      return const [];
    }
  }

  /// Atualiza a última mensagem de uma conversa no resumo local (lojas e pessoas).
  static Future<void> atualizarUltimaMensagem(
    String conversaId,
    String conteudo,
    DateTime enviadaEm,
  ) async {
    if (conversaId.isEmpty) return;

    // Atualiza lojas se presente
    if (_conversasLojasMemoria != null) {
      final index = _conversasLojasMemoria!.indexWhere((c) => c.id == conversaId);
      if (index != -1) {
        final atual = _conversasLojasMemoria![index];
        _conversasLojasMemoria![index] = atual.copyWith(
          ultimaMensagem: conteudo,
          ultimaMensagemData: enviadaEm,
        );
        salvarConversasLojas(_conversasLojasMemoria!);
      }
    }

    // Atualiza pessoas se presente
    if (_conversasPessoasMemoria != null) {
      final index = _conversasPessoasMemoria!.indexWhere((c) => c.id == conversaId);
      if (index != -1) {
        final atual = _conversasPessoasMemoria![index];
        _conversasPessoasMemoria![index] = atual.copyWith(
          ultimaMensagem: conteudo,
          ultimaMensagemData: enviadaEm,
        );
        salvarConversasPessoas(_conversasPessoasMemoria!);
      }
    }
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
