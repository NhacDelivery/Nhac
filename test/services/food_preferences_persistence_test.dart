import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nhac/services/local_cache_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'preferências sobrevivem à limpeza da sessão e não passam para outra conta',
    () async {
      await LocalCacheService.salvarPreferenciasComida('u1', {
        'Vegetariana',
        'Doces',
      });
      await LocalCacheService.limparTudo();
      expect(await LocalCacheService.carregarPreferenciasComida('u1'), {
        'Vegetariana',
        'Doces',
      });
      expect(await LocalCacheService.carregarPreferenciasComida('u2'), isEmpty);
      await LocalCacheService.salvarPreferenciasComida('u1', {'Doces'});
      expect(await LocalCacheService.carregarPreferenciasComida('u1'), {
        'Doces',
      });
    },
  );
}
