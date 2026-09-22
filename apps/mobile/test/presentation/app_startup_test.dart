import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapless_ai/core/routing/app_router.dart';
import 'package:mapless_ai/main.dart';

void main() {
  group('App Startup & Lifecycle', () {
    testWidgets('App initializes cleanly with ProviderScope and default route', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MapLessApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MapLessApp), findsOneWidget);
    });

    testWidgets('App can launch directly into Splash route', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MapLessApp(initialRoute: AppRouter.splash),
        ),
      );
      // Pump initial frame of splash screen without settling navigation delay
      await tester.pump();

      expect(find.text('MapLess AI'), findsOneWidget);
      expect(find.text('v1.0.0 • Spatial Intelligence Platform'), findsOneWidget);

      // Advance past splash delay to allow route to transition cleanly
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    });
  });
}
