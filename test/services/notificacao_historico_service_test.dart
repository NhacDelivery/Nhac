import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nhac/services/notificacao_historico_service.dart';

void main() {
  test('avisos locais não aparecem em outra conta e não duplicam por ID', () async {
    SharedPreferences.setMockInitialValues({});
    final aviso = NotificacaoRegistrada('m1', 'Pedido em preparo', 'A loja começou', DateTime.utc(2026, 9, 28));
    await NotificacaoHistoricoService.registrar('cliente-a', aviso);
    await NotificacaoHistoricoService.registrar('cliente-a', aviso);
    expect((await NotificacaoHistoricoService.listar('cliente-a')).length, 1);
    expect(await NotificacaoHistoricoService.listar('cliente-b'), isEmpty);
  });
}
