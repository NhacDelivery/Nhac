/// Helpers para parsing seguro de valores dinâmicos vindos do backend.
/// Evita TypeError e NoSuchMethodError quando o backend retorna tipos
/// inesperados (String ao invés de int, HTML ao invés de JSON, etc.)
library;

/// Extrai conteúdo paginado ou lista direta de uma resposta da API.
/// Lida com o caso em que response.data pode ser Map (paginado) ou List.
List<dynamic> extrairLista(dynamic data, {String chave = 'content'}) {
  if (data is Map) return (data[chave] as List?) ?? [];
  if (data is List) return data;
  return [];
}

/// Extrai mensagem de erro de uma resposta de exceção Dio.
/// Seguro contra respostas HTML/texto puro (ex: 502 Bad Gateway do Nginx).
String extrairMensagemErro(dynamic data,
    {String fallback = 'Erro desconhecido'}) {
  if (data is Map) return data['message']?.toString() ?? fallback;
  if (data is String && data.isNotEmpty) return data;
  return fallback;
}

/// Parse seguro de int de qualquer tipo dinâmico.
int safeInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

/// Parse seguro de double de qualquer tipo dinâmico.
double safeDouble(dynamic value, {double fallback = 0.0}) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

/// Parse seguro de bool de qualquer tipo dinâmico.
bool safeBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  if (value is int) return value != 0;
  return fallback;
}
