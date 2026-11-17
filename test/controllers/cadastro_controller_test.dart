import 'package:flutter_test/flutter_test.dart';
import 'package:nhac/controllers/cadastro_controller.dart';

void main() {
  test('prova pertence ao e-mail e é descartada ao trocar identidade', () {
    final controller = CadastroController();
    addTearDown(controller.dispose);
    controller.setEmail('cliente@exemplo.com');
    controller.setTokenCadastro('prova');
    controller.setEmail(' CLIENTE@EXEMPLO.COM ');
    expect(controller.tokenCadastro, 'prova');
    controller.setEmail('outro@exemplo.com');
    expect(controller.tokenCadastro, isNull);
    controller.setTokenCadastro('nova-prova');
    controller.invalidarTokenCadastro();
    expect(controller.tokenCadastro, isNull);
    controller.setTokenCadastro('outra-prova');
    controller.limparDados();
    expect(controller.tokenCadastro, isNull);
  });

  group('Testes do CadastroController (O Cérebro da Tela)', () {
    
    test('Deve guardar o nome, email e telefone corretamente na memória', () {
      final controller = CadastroController();

      controller.setNome('Matheus Sênior');
      controller.setEmail('matheus@teste.com');
      controller.setTelefone('11999999999');

      expect(controller.nome, 'Matheus Sênior');
      expect(controller.email, 'matheus@teste.com');
      expect(controller.telefone, '11999999999');
    });

    test('Deve apagar tudo quando chamar limparDados()', () {
      final controller = CadastroController();

      controller.setNome('Matheus');
      controller.limparDados();

      expect(controller.nome, '');
    });

  });
}