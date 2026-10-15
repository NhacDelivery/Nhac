import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhac/globals/exceptions.dart';
import 'package:nhac/models/pedido/criar_pedido_request.dart';
import 'package:nhac/models/pedido/pedido_criado_response.dart';
import 'package:nhac/models/usuario/endereco_model.dart';
import 'package:nhac/repositories/pedido_repository.dart';
import 'package:nhac/services/checkout_tentativa_service.dart';

class RepoTentativa extends Mock implements PedidoRepository {}

class StorageTentativa extends Mock implements FlutterSecureStorage {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RepoTentativa repo;
  CriarPedidoRequest pedido() => CriarPedidoRequest(
          lojaId: 'loja',
          formaPagamento: 'DINHEIRO',
          enderecoEntrega: EnderecoModel(
              rua: 'Rua A',
              numero: '1',
              bairro: 'Centro',
              cidade: 'Osasco',
              estado: 'SP',
              cep: '06000000'),
          itens: const [
            CriarPedidoItemRequest(
                produtoId: 'p1', nome: 'Produto', quantidade: 1)
          ]);
  setUp(() {
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8080');
    FlutterSecureStorage.setMockInitialValues({});
    repo = RepoTentativa();
  });

  test('reiniciar serviço após timeout reenvia payload e chave originais',
      () async {
    final payloads = <Map<String, dynamic>>[];
    final chaves = <String>[];
    when(() => repo.recuperarTentativaCheckout(any(),
        idempotencyKey: any(named: 'idempotencyKey'))).thenAnswer((call) async {
      payloads.add(
          Map<String, dynamic>.from(call.positionalArguments.first as Map));
      chaves.add(call.namedArguments[#idempotencyKey] as String);
      if (chaves.length == 1) throw TimeoutException('Resposta perdida');
      return const PedidoCriadoResponse(pedidoId: 'existente', replay: true);
    });
    await expectLater(
        CheckoutTentativaService(repository: repo).enviar('cliente', pedido()),
        throwsA(isA<TimeoutException>()));
    final reiniciado = CheckoutTentativaService(repository: repo);
    expect(await reiniciado.carregar('outra-conta'), isNull);
    await expectLater(reiniciado.enviar('cliente', pedido()), throwsStateError);
    expect((await reiniciado.recuperar('cliente')).pedidoId, 'existente');
    expect(chaves[1], chaves[0]);
    expect(payloads[1], payloads[0]);
    // Confirmação persistida recupera sem repetir a chamada HTTP.
    await reiniciado.recuperar('cliente');
    expect(chaves.length, 2);
    await reiniciado.concluir('cliente');
    expect(await reiniciado.carregar('cliente'), isNull);
  });

  test('falha de armazenamento impede POST e não perde proteção', () async {
    final storage = StorageTentativa();
    when(() => storage.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);
    when(() =>
            storage.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenThrow(Exception('Disco indisponível'));
    await expectLater(
        CheckoutTentativaService(storage: storage, repository: repo)
            .enviar('cliente', pedido()),
        throwsException);
    verifyNever(() => repo.recuperarTentativaCheckout(any(),
        idempotencyKey: any(named: 'idempotencyKey')));
  });

  test('dois serviços da mesma conta não iniciam dois POSTs', () async {
    final resposta = Completer<PedidoCriadoResponse>();
    when(() => repo.recuperarTentativaCheckout(any(),
            idempotencyKey: any(named: 'idempotencyKey')))
        .thenAnswer((_) => resposta.future);
    final primeira =
        CheckoutTentativaService(repository: repo).enviar('cliente', pedido());
    await expectLater(
        CheckoutTentativaService(repository: repo).enviar('cliente', pedido()),
        throwsStateError);
    resposta.complete(const PedidoCriadoResponse(pedidoId: 'um'));
    await primeira;
    verify(() => repo.recuperarTentativaCheckout(any(),
        idempotencyKey: any(named: 'idempotencyKey'))).called(1);
  });

  test('conflito de idempotência conserva tentativa para recuperação',
      () async {
    when(() => repo.recuperarTentativaCheckout(any(),
            idempotencyKey: any(named: 'idempotencyKey')))
        .thenThrow(CustomCheckoutException(
            title: 'Conflito',
            message: 'Payload diferente',
            code: 'IDEMPOTENCIA_CONFLITO'));
    final service = CheckoutTentativaService(repository: repo);
    await expectLater(service.enviar('cliente', pedido()),
        throwsA(isA<CustomCheckoutException>()));
    expect(await service.carregar('cliente'), isNotNull);
  });

  test('rejeição definitiva permite corrigir a compra e tentar novamente',
      () async {
    when(() => repo.recuperarTentativaCheckout(any(),
            idempotencyKey: any(named: 'idempotencyKey')))
        .thenThrow(CustomCheckoutException(
            title: 'Loja fechada',
            message: 'Loja fechada',
            code: 'LOJA_FECHADA'));
    final service = CheckoutTentativaService(repository: repo);
    await expectLater(service.enviar('cliente', pedido()),
        throwsA(isA<CustomCheckoutException>()));
    expect(await service.carregar('cliente'), isNull);
  });
}
