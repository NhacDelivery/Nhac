import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhac/pages/search_page.dart';

void main() {
  setUpAll(() => dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8080'));
  testWidgets('SearchPage deve renderizar o campo de busca e aceitar input', (WidgetTester tester) async {
    
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) {
          return const MaterialApp(
            home: SearchPage(),
          );
        },
      ),
    );

   
    await tester.pumpAndSettle();

    
    // SearchPage não usa AppBar: a barra de busca é custom (Row com botão
    // de voltar + campo de texto arredondado), ver _buildBarraBusca().
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    
    await tester.enterText(find.byType(TextField), 'pizza');
    await tester.pump();

    // Verificar se o texto foi digitado
    expect(find.text('pizza'), findsOneWidget);
  });
}
