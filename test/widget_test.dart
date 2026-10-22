import 'package:flutter_test/flutter_test.dart';
import 'package:kotatsu/main.dart';

void main() {
  testWidgets('Kotatsu app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const KotatsuApp());
    expect(find.text('Kotatsu'), findsOneWidget);
  });
}
