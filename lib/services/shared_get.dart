import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';

typedef _RequestKey = ({
  int session,
  String baseUrl,
  String? auth,
  String path,
  String parameters
});

/// Cache por cliente HTTP, sessão, URI e parâmetros. Erros nunca são cacheados.
class SharedGet {
  static final _clients = Expando<SharedGet>();
  static int _session = 0;
  static int get sessionGeneration => _session;
  final _pending = <_RequestKey, Future<Response<dynamic>>>{};
  final _cache =
      <_RequestKey, ({DateTime expires, Response<dynamic> response})>{};
  int _generation = 0;

  static SharedGet forClient(Dio dio) => _clients[dio] ??= SharedGet();

  static void newSession() => _session++;

  void invalidate() {
    _generation++;
    _cache.clear();
    _pending.clear();
  }

  void invalidatePath(String path) {
    _cache.removeWhere((key, _) => key.path == path);
    _pending.removeWhere((key, _) => key.path == path);
  }

  void invalidatePrefix(String prefix) {
    _cache.removeWhere((key, _) => key.path.startsWith(prefix));
    _pending.removeWhere((key, _) => key.path.startsWith(prefix));
  }

  Future<Response<dynamic>> get(Dio dio, String path,
      {Map<String, dynamic>? queryParameters, Duration? validity}) {
    validity ??= path.startsWith('/produtos') || path.startsWith('/lojas')
        ? const Duration(minutes: 2)
        : const Duration(seconds: 5);
    final params = (queryParameters?.entries.toList() ?? [])
      ..sort((a, b) => a.key.compareTo(b.key));
    final key = (
      session: _session,
      baseUrl: dio.options.baseUrl,
      auth: dio.options.headers['Authorization']?.toString(),
      path: path,
      parameters:
          jsonEncode({for (final entry in params) entry.key: entry.value})
    );
    _cache.removeWhere((_, entry) => DateTime.now().isAfter(entry.expires));
    final cached = _cache[key];
    if (cached != null && DateTime.now().isBefore(cached.expires)) {
      return Future.value(cached.response);
    }
    final existing = _pending[key];
    if (existing != null) return existing;
    final generation = _generation;
    late final Future<Response<dynamic>> operation;
    operation = dio
        .get<dynamic>(path, queryParameters: queryParameters)
        .then((response) {
      if (generation == _generation &&
          key.session == _session &&
          identical(_pending[key], operation)) {
        if (_cache.length >= 128) _cache.remove(_cache.keys.first);
        _cache[key] =
            (expires: DateTime.now().add(validity!), response: response);
      }
      return response;
    }).whenComplete(() {
      if (identical(_pending[key], operation)) _pending.remove(key);
    });
    _pending[key] = operation;
    return operation;
  }
}
