import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhac/models/pedido/status_pedido.dart';
import 'package:nhac/pages/qrcode_pix_page.dart';
import 'package:nhac/repositories/pedido_repository.dart';
import 'package:nhac/services/pedido_status_socket_service.dart';

class PixRepo extends Mock implements PedidoRepository {}

class PixSocket extends Mock implements PedidoStatusSocketService {}

void main() {
  Future<PixRepo> montar(WidgetTester tester,
      {Size size = const Size(390, 844)}) async {
    final repo = PixRepo();
    final socket = PixSocket();
    when(() => repo.buscarPedidoPorId(any())).thenThrow(Exception('Offline'));
    when(() => socket.status)
        .thenAnswer((_) => const Stream<StatusPedido>.empty());
    when(() => socket.conectar(any())).thenAnswer((_) async {});
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
            home: QrCodePixPage(
                pixQrCode: 'teste-pix',
                paymentId: 'p1',
                valor: 12,
                pedidoRepository: repo,
                statusSocket: socket))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    return repo;
  }

  testWidgets(
      'falha inicial informa indisponibilidade e oferece consulta manual',
      (tester) async {
    final repo = await montar(tester, size: const Size(320, 1000));
    expect(find.text('Pagamento ainda não verificado'), findsOneWidget);
    expect(find.text('Já paguei, verificar pedido'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Já paguei, verificar pedido'));
    await tester.pump();
    verify(() => repo.buscarPedidoPorId('p1')).called(2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'limite automático mantém verificação manual e ação de acompanhar',
      (tester) async {
    final repo = await montar(tester);
    for (var i = 0; i < 84; i++) {
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
    }
    expect(find.text('Já paguei, verificar pedido'), findsOneWidget);
    expect(find.text('Acompanhar pedido'), findsOneWidget);
    clearInteractions(repo);
    await tester.pump(const Duration(minutes: 1));
    verifyNever(() => repo.buscarPedidoPorId('p1'));
    await tester.ensureVisible(find.text('Já paguei, verificar pedido'));
    await tester.tap(find.text('Já paguei, verificar pedido'));
    await tester.pump();
    verify(() => repo.buscarPedidoPorId('p1')).called(1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
