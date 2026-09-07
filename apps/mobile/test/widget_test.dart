import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapless_ai/main.dart';

void main() {
  testWidgets('MapLess AI starter app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: MapLessApp(),
      ),
    );

    // Verify app title displays
    expect(find.text('MapLess AI'), findsWidgets);

    // Verify feature module cards display
    expect(find.text('Indoor Map View'), findsOneWidget);
    expect(find.text('Creator Mapping'), findsOneWidget);
    expect(find.text('Spatial Route'), findsOneWidget);
    expect(find.text('AI Assistant'), findsOneWidget);
    expect(find.text('Version History'), findsOneWidget);
  });
}
