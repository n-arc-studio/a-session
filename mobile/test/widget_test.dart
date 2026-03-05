import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/main.dart';

void main() {
  testWidgets('A:SESSION app renders', (WidgetTester tester) async {
    await tester.pumpWidget(const ASessionApp());
    expect(find.byType(ASessionApp), findsOneWidget);
  });
}
