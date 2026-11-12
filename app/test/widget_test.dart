import 'package:flutter_test/flutter_test.dart';
import 'package:pro_servico/main.dart';

void main() {
  testWidgets('App inicia na tela de login', (WidgetTester tester) async {
    await tester.pumpWidget(const ProServicoApp());
    await tester.pump();
    expect(find.textContaining('Bem-vindo de volta'), findsOneWidget);
    expect(find.text('Entrar'), findsWidgets);
  });
}
