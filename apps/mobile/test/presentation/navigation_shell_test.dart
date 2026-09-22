import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapless_ai/core/state/auth_state.dart';
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

    testWidgets('HomeShellScreen does not produce RenderFlex overflow at 360 width', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HomeShellScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(HomeShellScreen), findsOneWidget);
    });

    testWidgets('HomeShellScreen with authenticated Creator user renders without overflow at 360x800', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => AuthController()
            ..state = const AuthState(
              status: AuthStatus.authenticated,
              user: AppUser(
                id: 'usr-creator',
                name: 'Nishant',
                email: 'creator@mapless.ai',
                role: UserRole.creator,
              ),
            )),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: HomeShellScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('CREATOR'), findsOneWidget);

      // Switch to Creator Mapping tab (tab index 2)
      await tester.tap(find.text('Creator'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Indoor Map Creator Hub'), findsOneWidget);
      expect(find.text('Phase 4 Sensor Engine (PDR & Orientation)'), findsOneWidget);
    });

    testWidgets('HomeShellScreen with authenticated Creator user renders without overflow at 390x844', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => AuthController()
            ..state = const AuthState(
              status: AuthStatus.authenticated,
              user: AppUser(
                id: 'usr-creator',
                name: 'Nishant',
                email: 'creator@mapless.ai',
                role: UserRole.creator,
              ),
            )),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: HomeShellScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('CREATOR'), findsOneWidget);

      await tester.tap(find.text('Creator'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Indoor Map Creator Hub'), findsOneWidget);
      expect(find.text('Phase 4 Sensor Engine (PDR & Orientation)'), findsOneWidget);
    });

    testWidgets('HomeShellScreen with authenticated Creator user renders without overflow at 430x932', (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => AuthController()
            ..state = const AuthState(
              status: AuthStatus.authenticated,
              user: AppUser(
                id: 'usr-creator',
                name: 'Nishant',
                email: 'creator@mapless.ai',
                role: UserRole.creator,
              ),
            )),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: HomeShellScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('CREATOR'), findsOneWidget);

      await tester.tap(find.text('Creator'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Indoor Map Creator Hub'), findsOneWidget);
      expect(find.text('Phase 4 Sensor Engine (PDR & Orientation)'), findsOneWidget);
    });

    testWidgets('HomeShellScreen navigates through all 5 tabs without RenderFlex overflow at 360x800', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => AuthController()
            ..state = const AuthState(
              status: AuthStatus.authenticated,
              user: AppUser(
                id: 'usr-creator',
                name: 'Nishant',
                email: 'creator@mapless.ai',
                role: UserRole.creator,
              ),
            )),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: HomeShellScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Tab 1: Map
      await tester.tap(find.text('Map'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Tab 2: Creator
      await tester.tap(find.text('Creator'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Phase 4 Sensor Engine (PDR & Orientation)'), findsOneWidget);

      // Tab 3: Routes
      await tester.tap(find.text('Routes'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Tab 4: AI Chat
      await tester.tap(find.text('AI Chat'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Return to Tab 0: Home
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
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
