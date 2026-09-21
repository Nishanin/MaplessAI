import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapless_ai/core/constants/app_strings.dart';
import 'package:mapless_ai/features/mapping/presentation/screens/splash_screen.dart';

void main() {
  group('Splash Screen UI & Flow', () {
    testWidgets('Displays branding elements and loading indicator', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SplashScreen(autoNavigate: false),
          ),
        ),
      );

      // Verify branding and logo
      expect(find.text(AppStrings.appName), findsOneWidget);
      expect(find.text(AppStrings.appTagline), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.hub_outlined), findsOneWidget);
      expect(find.text('v1.0.0 • Spatial Intelligence Platform'), findsOneWidget);
    });

    testWidgets('Navigates after delay when autoNavigate is enabled', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            routes: {
              '/login': (context) => const Scaffold(body: Text('Login Screen Mock')),
            },
            home: const SplashScreen(
              autoNavigate: true,
              delay: Duration(milliseconds: 100),
            ),
          ),
        ),
      );

      // Initially on Splash
      expect(find.text(AppStrings.appName), findsOneWidget);

      // Advance clock past the delay
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      // Should have navigated to login route
      expect(find.text('Login Screen Mock'), findsOneWidget);
    });
  });
}
