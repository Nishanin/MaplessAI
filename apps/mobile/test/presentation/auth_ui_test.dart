import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapless_ai/core/routing/app_router.dart';
import 'package:mapless_ai/core/state/auth_state.dart';
import 'package:mapless_ai/core/widgets/app_button.dart';
import 'package:mapless_ai/features/mapping/presentation/screens/login_screen.dart';
import 'package:mapless_ai/features/mapping/presentation/screens/register_screen.dart';

void main() {
  group('Authentication UI & State Machine', () {
    testWidgets('LoginScreen displays all input fields and quick fill button', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Fill Test Account (Nishant)'), findsOneWidget);
    });

    testWidgets('Login validates empty inputs and shows error messages', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Tap Sign In without filling fields
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('Quick fill button populates test credentials', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      await tester.tap(find.text('Fill Test Account (Nishant)'));
      await tester.pumpAndSettle();

      expect(find.text('nishant@mapless.ai'), findsOneWidget);
      expect(find.text('creator123'), findsOneWidget);
    });

    testWidgets('Shows error banner when login credentials fail', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Enter failing email
      await tester.enterText(find.byType(TextFormField).first, 'fail@test.com');
      await tester.enterText(find.byType(TextFormField).last, 'password123');
      await tester.tap(find.text('Sign In'));

      // Settle simulated network handshake
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Invalid credentials. Please verify your email and password.'), findsOneWidget);
    });

    testWidgets('RegisterScreen displays name, email, password, and role selector', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: RegisterScreen(),
          ),
        ),
      );

      expect(find.text('Create Account'), findsNWidgets(2));
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Select Your Role'), findsOneWidget);
      expect(find.text('Creator / Staff'), findsOneWidget);
      expect(find.text('Visitor'), findsOneWidget);
    });

    testWidgets('Successful registration updates auth state and user role', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            initialRoute: '/register',
            routes: {
              '/register': (_) => const RegisterScreen(),
              AppRouter.home: (_) => const Scaffold(body: Text('Home Target Screen')),
            },
          ),
        ),
      );

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'Nishant Tester');
      await tester.enterText(textFields.at(1), 'nishant.dev@mapless.ai');
      await tester.enterText(textFields.at(2), 'securePass123');

      await tester.tap(find.widgetWithText(AppButton, 'Create Account'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      final auth = container.read(authProvider);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.user?.name, equals('Nishant Tester'));
      expect(auth.user?.role, equals(UserRole.creator));
      expect(find.text('Home Target Screen'), findsOneWidget);
    });

    test('Logout clears user and transitions to unauthenticated state', () async {
      final controller = AuthController();
      expect(controller.state.status, equals(AuthStatus.initial));

      await controller.login('nishant@mapless.ai', 'creator123');
      expect(controller.state.isAuthenticated, isTrue);

      controller.logout();
      expect(controller.state.status, equals(AuthStatus.unauthenticated));
      expect(controller.state.user, isNull);
    });
  });
}
