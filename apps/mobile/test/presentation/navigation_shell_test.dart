import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapless_ai/core/widgets/app_navigation_shell.dart';
import 'package:mapless_ai/features/mapping/presentation/screens/home_shell_screen.dart';
import 'package:mapless_ai/features/mapping/presentation/widgets/map_controls.dart';

void main() {
  group('Navigation Shell & Map Controls Verification', () {
    testWidgets('AppNavigationBar renders all five primary tabs', (tester) async {
      int selectedIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: AppNavigationBar(
              currentIndex: selectedIndex,
              onDestinationSelected: (index) => selectedIndex = index,
            ),
          ),
        ),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Map'), findsOneWidget);
      expect(find.text('Creator'), findsOneWidget);
      expect(find.text('Routes'), findsOneWidget);
      expect(find.text('AI Chat'), findsOneWidget);

      // Tap on Map tab (index 1)
      await tester.tap(find.text('Map'));
      await tester.pump();
      expect(selectedIndex, equals(1));
    });

    testWidgets('HomeShellScreen renders top bar, user status chip, and switches destinations', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HomeShellScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top bar title
      expect(find.text('MapLess AI'), findsWidgets);

      // Verify dashboard content on initial tab 0
      expect(find.text('Feature Modules'), findsOneWidget);

      // Tap tab 1 (Map)
      await tester.tap(find.text('Map'));
      await tester.pumpAndSettle();

      // On Map View screen, we should see map view canvas title
      expect(find.text('Indoor Map Canvas'), findsWidgets);
    });

    testWidgets('MapFloatingControls triggers zoom and reset callbacks', (tester) async {
      bool zoomedIn = false;
      bool zoomedOut = false;
      bool reset = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapFloatingControls(
              currentFloorLabel: 'Floor 1',
              onZoomIn: () => zoomedIn = true,
              onZoomOut: () => zoomedOut = true,
              onResetView: () => reset = true,
            ),
          ),
        ),
      );

      expect(find.text('Floor 1'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.remove), findsOneWidget);
      expect(find.byIcon(Icons.center_focus_strong), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(zoomedIn, isTrue);

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
      expect(zoomedOut, isTrue);

      await tester.tap(find.byIcon(Icons.center_focus_strong));
      await tester.pump();
      expect(reset, isTrue);
    });
  });
}
