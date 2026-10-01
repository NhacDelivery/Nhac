import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nhac/models/pedido/status_pedido.dart';

class NotificacaoRegistrada {
  final String id, titulo, corpo;
  final DateTime recebidaEm;
  final String? pedidoId;
  final StatusPedido? status;
  const NotificacaoRegistrada(
    this.id,
    this.titulo,
    this.corpo,
    this.recebidaEm, {
    this.pedidoId,
    this.status,
  });

  factory NotificacaoRegistrada.fromJson(Map<String, dynamic> json) =>
      NotificacaoRegistrada(
        json['id']?.toString() ?? '',
        json['titulo']?.toString() ?? '',
        json['corpo']?.toString() ?? '',
        DateTime.tryParse(json['recebidaEm']?.toString() ?? '') ??
            DateTime.now(),
        pedidoId: json['pedidoId']?.toString(),
        status: json['status'] == null
            ? null
            : StatusPedido.fromApi(json['status'].toString()),
      );
  Map<String, dynamic> toJson() => {
        'id': id,
        'titulo': titulo,
        'corpo': corpo,
        'recebidaEm': recebidaEm.toIso8601String(),
        if (pedidoId != null) 'pedidoId': pedidoId,
        if (status != null) 'status': status!.apiValue,
      };
}

class NotificacaoHistoricoService {
  static final _alteracoes = StreamController<String>.broadcast();
  static Stream<String> get alteracoes => _alteracoes.stream;
  static String _chave(String usuarioId) => 'avisos_$usuarioId';
  static String _prefixo(String usuarioId) =>
      'aviso_v2:${Uri.encodeComponent(usuarioId)}:';

  static Future<List<NotificacaoRegistrada>> listar(String usuarioId) async =>
      (await _listarTodos(usuarioId)).take(50).toList();

  static Future<List<NotificacaoRegistrada>> _listarTodos(
      String usuarioId) async {
    final prefs = await SharedPreferences.getInstance();
    // O FCM usa outro isolate. Recarregar evita ler a cópia antiga em memória.
    await prefs.reload();
    final registros = <String>[
      ...?prefs.getStringList(_chave(usuarioId)),
      for (final key in prefs.getKeys().where(
            (key) => key.startsWith(_prefixo(usuarioId)),
          ))
        if (prefs.getString(key) != null) prefs.getString(key)!,
    ];
    final porId = <String, NotificacaoRegistrada>{};
    for (final raw in registros) {
      try {
        final aviso = NotificacaoRegistrada.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
        if (aviso.id.isNotEmpty) porId[aviso.id] = aviso;
      } catch (_) {
        // Um registro corrompido não deve esconder os outros avisos.
      }
    }
    return porId.values.toList()
      ..sort((a, b) => b.recebidaEm.compareTo(a.recebidaEm));
  }

  static Future<void> registrar(
    String usuarioId,
    NotificacaoRegistrada aviso,
  ) async {
    if (usuarioId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final key = '${_prefixo(usuarioId)}${Uri.encodeComponent(aviso.id)}';
    // Cada evento tem sua própria chave: gravações simultâneas não sobrescrevem a lista.
    if (prefs.containsKey(key)) return;
    await prefs.setString(key, jsonEncode(aviso.toJson()));
    final avisos = await _listarTodos(usuarioId);
    for (final antigo in avisos.skip(50)) {
      await prefs.remove(
        '${_prefixo(usuarioId)}${Uri.encodeComponent(antigo.id)}',
      );
    }
    _alteracoes.add(usuarioId);
  }

  static Future<void> registrarStatus(
    String usuarioId,
    String pedidoId,
    StatusPedido status, {
    String? titulo,
    String? corpo,
    DateTime? recebidaEm,
  }) async {
    if (status == StatusPedido.desconhecido) return;
    try {
      await registrar(
        usuarioId,
        NotificacaoRegistrada(
          'pedido:$pedidoId:${status.apiValue}',
          titulo ?? status.label,
          corpo ?? 'Seu pedido foi atualizado: ${status.label.toLowerCase()}.',
          recebidaEm ?? DateTime.now(),
          pedidoId: pedidoId,
          status: status,
        ),
      );
    } catch (e) {
      debugPrint('Não foi possível salvar o aviso do pedido: $e');
    }
  }
}
