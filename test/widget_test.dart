// This is a basic Flutter widget test.
import 'package:flutter_test/flutter_test.dart';

import 'package:identia/main.dart';

void main() {
  testWidgets('IDentia app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const IDentiaApp());

    // Verify that the app launches
    await tester.pumpAndSettle();
  });
}
