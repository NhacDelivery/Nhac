import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhac/components/home/home_category_chips.dart';
import 'package:nhac/repositories/produto_repository.dart';

class MockProdutoRepository extends Mock implements ProdutoRepository {}

void main() {
  late MockProdutoRepository mockRepository;

  setUp(() {
    mockRepository = MockProdutoRepository();
  });

  testWidgets('HomeCategoryChips renderiza chips com fundo branco e bordas arredondadas',
      (tester) async {
    when(() => mockRepository.buscarCategorias())
        .thenAnswer((_) async => ['Acompanhamento', 'Bebidas']);

    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(800, 600),
        builder: (_, __) => MaterialApp(
          home: Scaffold(
            body: HomeCategoryChips(repository: mockRepository),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Acompanhamento'), findsOneWidget);
    expect(find.text('Bebidas'), findsOneWidget);

    final chipFinder = find.byType(ActionChip);
    expect(chipFinder, findsNWidgets(2));

    final listViewFinder = find.byType(ListView);
    expect(listViewFinder, findsOneWidget);
    final listView = tester.widget<ListView>(listViewFinder);
    expect(listView.physics, isA<BouncingScrollPhysics>());

    final firstChip = tester.widget<ActionChip>(chipFinder.first);
    expect(firstChip.backgroundColor, Colors.white);
    expect(firstChip.surfaceTintColor, Colors.transparent);
    final shape = firstChip.shape as RoundedRectangleBorder;
    expect(shape.borderRadius, isA<BorderRadius>());
  });
}
