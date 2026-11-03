/// Retorna um identificador de apresentação compatível com o formato @handle.
///
/// O backend ainda não persiste usernames; por isso, o valor é derivado do
/// nome de exibição e não deve ser usado como chave de conta ou autenticação.
String usernameFromName(String name) {
  var value = name.trim().toLowerCase();
  const substitutions = <String, String>{
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c', 'ñ': 'n',
  };
  substitutions.forEach((from, to) => value = value.replaceAll(from, to));
  value = value
      .replaceAll(RegExp(r'[^a-z0-9]+'), '.')
      .replaceAll(RegExp(r'^\.+|\.+$'), '');
  return '@${value.isEmpty ? 'usuario' : value}';
}
