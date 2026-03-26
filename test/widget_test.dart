import 'package:flutter_test/flutter_test.dart';
import 'package:cki_demo/main.dart';

void main() {
  testWidgets('App starts', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('VOA Learning English'), findsOneWidget);
  });
}
