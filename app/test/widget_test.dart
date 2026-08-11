import 'package:flutter_test/flutter_test.dart';
import 'package:pro_servico/main.dart';

void main() {
  testWidgets('App inicia na tela de boas-vindas', (WidgetTester tester) async {
    await tester.pumpWidget(const ProServicoApp());
    expect(find.textContaining('Conectando quem precisa'), findsOneWidget);
    expect(find.text('Sou cliente'), findsOneWidget);
  });
}
