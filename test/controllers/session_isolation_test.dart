import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:nhac/controllers/endereco_provider.dart';
import 'package:nhac/controllers/user_provider.dart';
import 'package:nhac/controllers/cart_provider.dart';
import 'package:nhac/repositories/endereco_repository.dart';
import 'package:nhac/repositories/user_repository.dart';
import 'package:nhac/repositories/cart_repository.dart';
import 'package:nhac/models/usuario/endereco_model.dart';
import 'package:nhac/models/usuario/usuario_model.dart';

class SessionAuth extends ChangeNotifier implements AuthService {
  String? id = 'a';
  @override String? get usuarioId => id;
  void mudar(String? novoId) { id = novoId; notifyListeners(); }
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
class EnderecosMock extends Mock implements EnderecoRepository {}
class UsuarioMock extends Mock implements UserRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SessionAuth auth;
  setUp(() { auth = SessionAuth(); SharedPreferences.setMockInitialValues({}); });
  tearDown(() => auth.dispose());

  EnderecoModel endereco() => EnderecoModel(id: 'endereco-a', rua: 'Rua A', numero: '1', bairro: 'Centro', cidade: 'Cidade', estado: 'SP', cep: '00000-000');

  test('trocar conta limpa endereços mesmo se a nova consulta falhar', () async {
    final repo = EnderecosMock();
    when(() => repo.buscarEnderecos('a')).thenAnswer((_) async => [endereco()]);
    when(() => repo.buscarEnderecos('b')).thenThrow(Exception('Offline'));
    final provider = EnderecoProvider(authService: auth, repository: repo);
    await provider.buscarEnderecos();
    expect(provider.enderecos, hasLength(1));
    auth.mudar('b');
    expect(provider.enderecos, isEmpty);
    await provider.buscarEnderecos();
    expect(provider.enderecos, isEmpty);
    provider.dispose();
  });

  test('resposta de endereços da conta anterior é descartada', () async {
    final repo = EnderecosMock();
    final resposta = Completer<List<EnderecoModel>>();
    when(() => repo.buscarEnderecos('a')).thenAnswer((_) => resposta.future);
    final provider = EnderecoProvider(authService: auth, repository: repo);
    final consulta = provider.buscarEnderecos();
    auth.mudar(null);
    auth.mudar('b');
    resposta.complete([endereco()]);
    await consulta;
    expect(provider.enderecos, isEmpty);
    provider.dispose();
  });

  test('perfil atrasado não reaparece depois do logout', () async {
    final repo = UsuarioMock();
    final resposta = Completer<UsuarioModel>();
    when(() => repo.buscarUsuario('a')).thenAnswer((_) => resposta.future);
    final provider = UserProvider(authService: auth, repository: repo);
    final consulta = provider.carregarDadosUsuario();
    auth.mudar(null);
    resposta.complete(UsuarioModel(id: 'a', nome: 'Cliente A', email: 'a@teste.com', telefone: '11999999999', imagemUrl: ''));
    await consulta;
    expect(provider.usuario, isNull);
    provider.dispose();
  });

  test('carrinho em memória e cache são isolados por conta', () async {
    final provider = CartProvider(authService: auth);
    await provider.adicionarItemComQuantidade(idProduto: 'p', nome: 'Produto', preco: 10, imagemUrl: '', lojaId: 'loja', quantidade: 1);
    expect(provider.quantidadeItens, 1);
    auth.mudar('b');
    expect(provider.quantidadeItens, 0);
    await provider.carregarCarrinhoLocal();
    expect(provider.quantidadeItens, 0);
    expect(await CartRepository(usuarioId: 'a').carregarCarrinhoLocal(), hasLength(1));
    provider.dispose();
  });
}
