import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:nhac/globals/app_constants.dart';

class FeedTentativaService {
  final FlutterSecureStorage storage;
  const FeedTentativaService({this.storage = const FlutterSecureStorage()});
  String _key(String uid, String scope) =>
      'nhac_feed:${AppConstants.apiBaseUrl}:$uid:$scope';
  Future<Map<String, dynamic>?> carregar(String uid, String scope) async {
    final raw = await storage.read(key: _key(uid, scope));
    return raw == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<Map<String, dynamic>> preparar(
    String uid,
    String scope,
    Map<String, dynamic> payload,
  ) async {
    final anterior = await carregar(uid, scope);
    if (anterior != null) {
      if (jsonEncode(anterior['payload']) != jsonEncode(payload)) {
        throw StateError(
          'Confirme o envio anterior antes de alterar o conteúdo.',
        );
      }
      return anterior;
    }
    final tentativa = {'key': const Uuid().v4(), 'payload': payload};
    await storage.write(key: _key(uid, scope), value: jsonEncode(tentativa));
    return tentativa;
  }

  Future<void> concluir(String uid, String scope) =>
      storage.delete(key: _key(uid, scope));
}
