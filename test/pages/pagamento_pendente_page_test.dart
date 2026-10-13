import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhac/globals/exceptions.dart';
import 'package:nhac/models/pedido/pagamento_pendente_model.dart';
import 'package:nhac/models/pedido/status_pedido.dart';
import 'package:nhac/pages/pagamento_pendente_page.dart';
import 'package:nhac/repositories/pedido_repository.dart';

class PagamentoRepo extends Mock implements PedidoRepository {}

void main() {
  late PagamentoRepo repo;
  setUp(() {
    repo = PagamentoRepo();
    when(() => repo.buscarPedidoPorId('p1')).thenThrow(Exception('offline'));
  });

  Future<void> montar(WidgetTester tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          home: PagamentoPendentePage(pedidoId: 'p1', repository: repo),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'PIX temporariamente indisponível não afirma que o prazo terminou',
    (tester) async {
      const mensagem =
          'Não foi possível carregar o PIX agora. Tente novamente em instantes.';
      when(
        () => repo.buscarPagamento('p1'),
      ).thenThrow(AppException(mensagem, code: 'PAGAMENTO_INDISPONIVEL'));
      await montar(tester);
      expect(find.text(mensagem), findsOneWidget);
      expect(find.textContaining('O prazo para pagar terminou'), findsNothing);
      expect(find.text('Tentar novamente'), findsOneWidget);
    },
  );

  testWidgets('indisponibilidade de rede permite recuperar a mesma cobrança', (
    tester,
  ) async {
    when(() => repo.buscarPagamento('p1')).thenThrow(Exception('offline'));
    await montar(tester);
    expect(find.textContaining('Verifique a conexão'), findsOneWidget);
    when(() => repo.buscarPagamento('p1')).thenAnswer(
      (_) async => PagamentoPendenteModel(
        pedidoId: 'p1',
        formaPagamento: 'CARTAO',
        status: StatusPedido.pendente,
        expiraEm: DateTime.now().add(const Duration(minutes: 5)),
        valorTotal: 30,
        simulacaoDisponivel: false,
      ),
    );
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Pagar com cartão'), findsOneWidget);
    expect(find.textContaining('Verifique a conexão'), findsNothing);
    verify(() => repo.buscarPagamento('p1')).called(2);
    verify(() => repo.buscarPedidoPorId('p1')).called(1);
    verifyNoMoreInteractions(repo);
  });
}
