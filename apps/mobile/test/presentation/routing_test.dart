import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapless_ai/core/routing/app_router.dart';
import 'package:mapless_ai/core/routing/invalid_route_screen.dart';
import 'package:mapless_ai/features/mapping/presentation/screens/ai_chat_screen.dart';
import 'package:mapless_ai/features/mapping/presentation/screens/building_overview_screen.dart';
import 'package:mapless_ai/features/mapping/presentation/screens/buildings_screen.dart';
import 'package:mapless_ai/features/mapping/presentation/screens/creator_mapping_screen.dart';
import 'package:mapless_ai/features/mapping/presentation/screens/home_screen.dart';
import 'package:mapless_ai/features/mapping/presentation/screens/home_shell_screen.dart';
import 'package:mapless_ai/features/mapping/presentation/screens/login_screen.dart';
import 'package:mapless_ai/features/mapping/presentation/screens/map_view_screen.dart';
import 'package:mapless_ai/features/mapping/presentation/screens/navigation_screen.dart';
import 'package:mapless_ai/features/mapping/presentation/screens/profile_screen.dart';
import 'package:mapless_ai/features/mapping/presentation/screens/register_screen.dart';
import 'package:mapless_ai/features/mapping/presentation/screens/settings_screen.dart';
import 'package:mapless_ai/features/mapping/presentation/screens/splash_screen.dart';
import 'package:mapless_ai/features/mapping/presentation/screens/version_history_screen.dart';
import 'package:mapless_ai/features/mapping/presentation/screens/visitor_screen.dart';
import 'package:mapless_ai/main.dart';

void main() {
  group('Application Routing & Navigation Verification', () {
    testWidgets('All major routes exist and resolve to valid MaterialPageRoutes', (tester) async {
      final routesToTest = <String, Type>{
        AppRouter.splash: SplashScreen,
        AppRouter.login: LoginScreen,
        AppRouter.register: RegisterScreen,
        AppRouter.auth: LoginScreen,
        AppRouter.home: HomeShellScreen,
        AppRouter.homeShell: HomeShellScreen,
        AppRouter.dashboard: HomeScreen,
        AppRouter.buildings: BuildingsScreen,
        AppRouter.buildingOverview: BuildingOverviewScreen,
        AppRouter.creator: CreatorMappingScreen,
        AppRouter.visitor: VisitorScreen,
        AppRouter.map: MapViewScreen,
        AppRouter.mapView: MapViewScreen,
        AppRouter.navigation: NavigationScreen,
        AppRouter.aiAssistant: AiChatScreen,
        AppRouter.aiChat: AiChatScreen,
        AppRouter.versionHistory: VersionHistoryScreen,
        AppRouter.versioning: VersionHistoryScreen,
        AppRouter.profile: ProfileScreen,
        AppRouter.settings: SettingsScreen,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              for (final entry in routesToTest.entries) {
                final route = AppRouter.generateRoute(RouteSettings(name: entry.key));
                expect(route, isA<MaterialPageRoute>());

                final pageRoute = route as MaterialPageRoute;
                final widget = pageRoute.builder(context);
                expect(
                  widget.runtimeType,
                  equals(entry.value),
                  reason: 'Route ${entry.key} should resolve to ${entry.value}',
                );
              }
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('Forward and back navigation works across major destinations', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MapLessApp(initialRoute: AppRouter.home),
        ),
      );
      await tester.pumpAndSettle();

      // Forward to Buildings
      AppRouter.navigatorKey.currentState!.pushNamed(AppRouter.buildings);
      await tester.pumpAndSettle();
      expect(find.byType(BuildingsScreen), findsOneWidget);
      expect(find.text('Campus Buildings'), findsOneWidget);

      // Back navigation from Buildings
      AppRouter.navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byType(HomeShellScreen), findsOneWidget);

      // Forward to Visitor screen
      AppRouter.navigatorKey.currentState!.pushNamed(AppRouter.visitor);
      await tester.pumpAndSettle();
      expect(find.byType(VisitorScreen), findsOneWidget);
      expect(find.text('Visitor Exploration'), findsOneWidget);

      // Back navigation from Visitor
      AppRouter.navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byType(HomeShellScreen), findsOneWidget);

      // Forward to Profile screen
      AppRouter.navigatorKey.currentState!.pushNamed(AppRouter.profile);
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text('User Profile'), findsOneWidget);

      // Back navigation from Profile
      AppRouter.navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byType(HomeShellScreen), findsOneWidget);

      // Forward to Settings screen
      AppRouter.navigatorKey.currentState!.pushNamed(AppRouter.settings);
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      // Back navigation from Settings
      AppRouter.navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byType(HomeShellScreen), findsOneWidget);
    });

    testWidgets('Invalid route displays InvalidRouteScreen with diagnostic details and return home action', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MapLessApp(initialRoute: '/unknown-test-route-xyz'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(InvalidRouteScreen), findsOneWidget);
      expect(find.text('404 — Invalid Route'), findsOneWidget);
      expect(find.textContaining('/unknown-test-route-xyz'), findsOneWidget);
      expect(find.text('Return to Home'), findsOneWidget);

      // Tap Return to Home
      await tester.tap(find.text('Return to Home'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeShellScreen), findsOneWidget);
    });

    testWidgets('Nested navigation in HomeShellScreen supports direct initial tab specification', (tester) async {
      final route = AppRouter.generateRoute(
        const RouteSettings(name: AppRouter.homeShell, arguments: 3),
      );
      expect(route, isA<MaterialPageRoute>());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            onGenerateRoute: AppRouter.generateRoute,
            home: const HomeShellScreen(initialTabIndex: 3),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tab index 3 is NavigationScreen
      expect(find.text('Indoor Route Guidance'), findsOneWidget);
    });
  });
}
