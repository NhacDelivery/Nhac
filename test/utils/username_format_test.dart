import 'package:flutter_test/flutter_test.dart';
import 'package:nhac/utils/username_format.dart';

void main() {
  test('normaliza nome com acentos para handle legível', () {
    expect(usernameFromName('  João da Silva  '), '@joao.da.silva');
  });

  test('usa fallback quando o nome não contém letras ou números', () {
    expect(usernameFromName('---'), '@usuario');
  });
}
