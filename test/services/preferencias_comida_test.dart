import 'package:flutter_test/flutter_test.dart';
import 'package:nhac/services/local_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('salva e recarrega as preferências do usuário', () async {
    expect(await LocalCacheService.carregarPreferenciasComida('u1'), isEmpty);
    await LocalCacheService.salvarPreferenciasComida('u1', {'Pizza', 'Doces'});
    expect(await LocalCacheService.carregarPreferenciasComida('u1'),
        {'Pizza', 'Doces'});
  });

  test('cada usuário tem as suas preferências', () async {
    await LocalCacheService.salvarPreferenciasComida('u1', {'Pizza'});
    expect(await LocalCacheService.carregarPreferenciasComida('u2'), isEmpty);
  });

  test('desmarcar tudo limpa a lista', () async {
    await LocalCacheService.salvarPreferenciasComida('u1', {'Pizza'});
    await LocalCacheService.salvarPreferenciasComida('u1', {});
    expect(await LocalCacheService.carregarPreferenciasComida('u1'), isEmpty);
  });
}
