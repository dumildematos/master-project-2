import 'package:flutter_test/flutter_test.dart';
import 'package:sentio_mobile/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SentioRoot());
    expect(find.text('SENTIO'), findsWidgets);
  });
}
