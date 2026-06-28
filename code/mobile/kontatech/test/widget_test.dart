import 'package:flutter_test/flutter_test.dart';
import 'package:kontatech/main.dart'; // Garanta que o caminho para o seu main.dart está correto

void main() {
  testWidgets('Kontatech smoke test - App render initialization', (WidgetTester tester) async {
    // Carrega o aplicativo Kontatech no ambiente de testes virtuais
    await tester.pumpWidget(const MyApp());

    // Verifica se o aplicativo inicializou a árvore de componentes com sucesso
    expect(find.byType(MyApp), findsOneWidget);
  });
}