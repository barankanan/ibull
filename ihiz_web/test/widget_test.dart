import 'package:flutter_test/flutter_test.dart';
import 'package:ihiz_web/main.dart';

void main() {
  testWidgets('Ihiz web landing ekranı açılır', (tester) async {
    await tester.pumpWidget(const IhizWebApp());
    await tester.pumpAndSettle();

    expect(find.text('İhız'), findsOneWidget);
    expect(
      find.text('İhız ile mağazadan al, müşteriye hızla teslim et.'),
      findsOneWidget,
    );
    expect(find.text('Kayıt Ol / Başvur'), findsWidgets);
  });
}
