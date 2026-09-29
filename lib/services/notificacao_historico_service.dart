import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class NotificacaoRegistrada {
  final String id, titulo, corpo;
  final DateTime recebidaEm;
  final String? pedidoId;
  const NotificacaoRegistrada(this.id, this.titulo, this.corpo, this.recebidaEm, {this.pedidoId});

  factory NotificacaoRegistrada.fromJson(Map<String, dynamic> json) => NotificacaoRegistrada(
    json['id']?.toString() ?? '', json['titulo']?.toString() ?? '',
    json['corpo']?.toString() ?? '', DateTime.tryParse(json['recebidaEm']?.toString() ?? '') ?? DateTime.now(),
    pedidoId: json['pedidoId']?.toString());
  Map<String, dynamic> toJson() => {'id': id, 'titulo': titulo, 'corpo': corpo,
    'recebidaEm': recebidaEm.toIso8601String(), if (pedidoId != null) 'pedidoId': pedidoId};
}

class NotificacaoHistoricoService {
  static String _chave(String usuarioId) => 'avisos_$usuarioId';

  static Future<List<NotificacaoRegistrada>> listar(String usuarioId) async {
    final prefs = await SharedPreferences.getInstance();
    final registros = prefs.getStringList(_chave(usuarioId)) ?? const [];
    return registros.map((raw) => NotificacaoRegistrada.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map))).toList();
  }

  static Future<void> registrar(String usuarioId, NotificacaoRegistrada aviso) async {
    final prefs = await SharedPreferences.getInstance();
    final existentes = prefs.getStringList(_chave(usuarioId)) ?? [];
    final atualizados = [jsonEncode(aviso.toJson()),
      ...existentes.where((raw) {
        try { return (jsonDecode(raw) as Map)['id'] != aviso.id; }
        catch (_) { return false; }
      })].take(50).toList();
    await prefs.setStringList(_chave(usuarioId), atualizados);
  }
}
