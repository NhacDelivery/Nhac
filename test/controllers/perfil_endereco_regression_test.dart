import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nhac/controllers/cart_provider.dart';
import 'package:nhac/controllers/endereco_provider.dart';
import 'package:nhac/controllers/user_provider.dart';
import 'package:nhac/models/usuario/endereco_model.dart';
import 'package:nhac/models/usuario/usuario_model.dart';
import 'package:nhac/repositories/cart_repository.dart';
import 'package:nhac/repositories/endereco_repository.dart';
import 'package:nhac/repositories/user_repository.dart';
import 'package:nhac/services/auth_service.dart';

class AuthMock extends Mock implements AuthService {}

class EnderecoMock extends Mock implements EnderecoRepository {}

class UserMock extends Mock implements UserRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final antigo = EnderecoModel(
      bairro: 'Centro',
      cidade: 'Osasco',
      estado: 'SP',
      cep: '06000000',
      id: 'antigo',
      rua: 'Rua A',
      numero: '1',
      isPadrao: true);
  final novo = EnderecoModel(
      bairro: 'Centro',
      cidade: 'Osasco',
      estado: 'SP',
      cep: '06000000',
      id: 'novo',
      rua: 'Rua B',
      numero: '',
      complemento: null);
  late AuthMock auth;
  setUpAll(() => registerFallbackValue(novo));
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    auth = AuthMock();
    when(() => auth.usuarioId).thenReturn('cliente');
  });

  test('falha inicial de perfil encerra loading e permite recuperar', () async {
    final repo = UserMock();
    when(() => repo.buscarUsuario('cliente')).thenThrow(Exception('offline'));
    final provider = UserProvider(authService: auth, repository: repo);
    await provider.carregarDadosUsuario();
    expect(provider.isLoading, false);
    expect(provider.usuario, isNull);
    expect(provider.erro, isNotNull);
    when(() => repo.buscarUsuario('cliente')).thenAnswer((_) async =>
        UsuarioModel(
            id: 'cliente',
            nome: 'Teste',
            email: 'teste@exemplo.com',
            telefone: '11999999999'));
    await provider.carregarDadosUsuario();
    expect(provider.usuario?.nome, 'Teste');
    expect(provider.erro, isNull);
    provider.dispose();
  });

  test('resposta nula do perfil é falha e não loading permanente', () async {
    final repo = UserMock();
    when(() => repo.buscarUsuario('cliente')).thenAnswer((_) async => null);
    final provider = UserProvider(authService: auth, repository: repo);
    await provider.carregarDadosUsuario();
    expect(provider.isLoading, false);
    expect(provider.erro, isNotNull);
    provider.dispose();
  });

  Future<EnderecoProvider> carregar(EnderecoMock repo) async {
    when(() => repo.buscarEnderecos('cliente'))
        .thenAnswer((_) async => [antigo, novo]);
    final provider = EnderecoProvider(authService: auth, repository: repo);
    await provider.buscarEnderecos();
    return provider;
  }

  test('troca de padrão usa somente um PUT e atualiza local após confirmação',
      () async {
    final repo = EnderecoMock();
    final provider = await carregar(repo);
    final resposta = Completer<void>();
    when(() => repo.atualizarEndereco('cliente', 'novo', any()))
        .thenAnswer((_) => resposta.future);
    final troca = provider.definirComoPadrao('novo');
    expect(provider.enderecos.first.isPadrao, true);
    expect(provider.isLoading, true);
    await expectLater(provider.definirComoPadrao('novo'), throwsStateError);
    resposta.complete();
    await troca;
    expect(provider.enderecos.where((e) => e.isPadrao).single.id, 'novo');
    final enviados =
        verify(() => repo.atualizarEndereco('cliente', 'novo', captureAny()))
            .captured;
    expect((enviados.single as EnderecoModel).isPadrao, true);
    verifyNever(() => repo.atualizarEndereco('cliente', 'antigo', any()));
    provider.dispose();
  });

  test('falha de troca preserva padrão anterior e chega ao chamador', () async {
    final repo = EnderecoMock();
    final provider = await carregar(repo);
    when(() => repo.atualizarEndereco('cliente', 'novo', any()))
        .thenThrow(Exception('offline'));
    await expectLater(provider.definirComoPadrao('novo'), throwsException);
    expect(provider.enderecos.where((e) => e.isPadrao).single.id, 'antigo');
    expect(provider.isLoading, false);
    verifyNever(() => repo.atualizarEndereco('cliente', 'antigo', any()));
    provider.dispose();
  });

  test('reiniciar carrinho restaura itens e observações na mesma conta',
      () async {
    final provider = CartProvider(authService: auth);
    await provider.adicionarItemComQuantidade(
        idProduto: 'p',
        nome: 'Pizza',
        preco: 20,
        imagemUrl: '',
        lojaId: 'loja',
        quantidade: 1);
    await provider.setObservacao('Sem cebola, por favor');
    provider.dispose();
    final restaurado = CartProvider(authService: auth);
    await restaurado.carregarCarrinhoLocal();
    expect(restaurado.quantidadeItens, 1);
    expect(restaurado.observacao, 'Sem cebola, por favor');
    expect(
        await CartRepository(usuarioId: 'outra-conta')
            .carregarObservacaoLocal(),
        '');
    await restaurado.excluirItemDoCarrinho('p');
    expect(restaurado.observacao, '');
    expect(await CartRepository(usuarioId: 'cliente').carregarObservacaoLocal(),
        '');
    restaurado.dispose();
  });

  test('cache antigo de carrinho continua legível sem observação', () async {
    SharedPreferences.setMockInitialValues({'@nhac_cart_items:cliente': '[]'});
    final provider = CartProvider(authService: auth);
    await provider.carregarCarrinhoLocal();
    expect(provider.itens, isEmpty);
    expect(provider.observacao, '');
    provider.dispose();
  });

  test('endereços distinguem erro de vazio e recuperam a consulta', () async {
    final repo = EnderecoMock();
    when(() => repo.buscarEnderecos('cliente')).thenThrow(Exception('offline'));
    final provider = EnderecoProvider(authService: auth, repository: repo);
    await provider.buscarEnderecos();
    expect(provider.erro, isNotNull);
    expect(provider.enderecos, isEmpty);
    when(() => repo.buscarEnderecos('cliente')).thenAnswer((_) async => []);
    await provider.buscarEnderecos();
    expect(provider.erro, isNull);
    provider.dispose();
  });

  test(
      'exclusão confirmada com refresh falho remove item e avisa sem repetir DELETE',
      () async {
    final repo = EnderecoMock();
    final provider = await carregar(repo);
    when(() => repo.removerEndereco('cliente', 'antigo'))
        .thenAnswer((_) async {});
    when(() => repo.buscarEnderecos('cliente')).thenThrow(Exception('offline'));
    await provider.removerEndereco('antigo');
    expect(provider.enderecos.map((e) => e.id), ['novo']);
    expect(provider.erro, contains('Alteração salva'));
    expect(provider.isLoading, false);
    verify(() => repo.removerEndereco('cliente', 'antigo')).called(1);
    provider.dispose();
  });

  test('resposta antiga dos endereços não substitui consulta mais recente',
      () async {
    final repo = EnderecoMock();
    final antiga = Completer<List<EnderecoModel>>();
    when(() => repo.buscarEnderecos('cliente'))
        .thenAnswer((_) => antiga.future);
    final provider = EnderecoProvider(authService: auth, repository: repo);
    final primeira = provider.buscarEnderecos();
    when(() => repo.buscarEnderecos('cliente')).thenAnswer((_) async => [novo]);
    await provider.buscarEnderecos();
    antiga.complete([antigo]);
    await primeira;
    expect(provider.enderecos.single.id, 'novo');
    provider.dispose();
  });
}
