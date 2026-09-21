import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapless_ai/core/widgets/app_button.dart';
import 'package:mapless_ai/core/widgets/app_card.dart';
import 'package:mapless_ai/core/widgets/app_dialogs.dart';
import 'package:mapless_ai/core/widgets/app_empty_state.dart';
import 'package:mapless_ai/core/widgets/app_error_state.dart';
import 'package:mapless_ai/core/widgets/app_status_chip.dart';
import 'package:mapless_ai/core/widgets/app_text_field.dart';
import 'package:mapless_ai/core/widgets/state_widgets.dart';

void main() {
  group('Design System & State Widgets Verification', () {
    testWidgets('AppLoading renders spinner with message and subtitle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppLoading(
              message: 'Generating Spatial Route...',
              subtitle: 'Analyzing floor graph edges',
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Generating Spatial Route...'), findsOneWidget);
      expect(find.text('Analyzing floor graph edges'), findsOneWidget);
    });

    testWidgets('ErrorDisplayWidget renders message and triggers onRetry', (tester) async {
      bool retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorDisplayWidget(
              message: 'Failed to connect to backend service',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('Failed to connect to backend service'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(retried, isTrue);
    });

    testWidgets('AppErrorState toggles technical details and triggers retry', (tester) async {
      bool retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppErrorState(
              title: 'Graph Sync Failed',
              message: 'Could not synchronize snapshot 12.',
              technicalDetails: 'HTTP 500: Internal server error at /api/v1/versioning',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('Graph Sync Failed'), findsOneWidget);
      expect(find.text('Could not synchronize snapshot 12.'), findsOneWidget);

      // Technical details are hidden by default
      expect(find.text('HTTP 500: Internal server error at /api/v1/versioning'), findsNothing);

      // Expand details
      await tester.tap(find.text('Show Error Details'));
      await tester.pumpAndSettle();
      expect(find.text('HTTP 500: Internal server error at /api/v1/versioning'), findsOneWidget);

      // Tap retry
      await tester.tap(find.text('Try Again'));
      await tester.pump();
      expect(retried, isTrue);
    });

    testWidgets('AppEmptyState displays custom title, message, and action button', (tester) async {
      bool actionTriggered = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppEmptyState(
              title: 'No Maps Found',
              message: 'You have not recorded any indoor floor plans yet.',
              actionLabel: 'Create First Map',
              actionIcon: Icons.add,
              onAction: () => actionTriggered = true,
            ),
          ),
        ),
      );

      expect(find.text('No Maps Found'), findsOneWidget);
      expect(find.text('You have not recorded any indoor floor plans yet.'), findsOneWidget);
      expect(find.text('Create First Map'), findsOneWidget);

      await tester.tap(find.text('Create First Map'));
      await tester.pump();
      expect(actionTriggered, isTrue);
    });

    testWidgets('AppStatusChip correctly renders different semantic statuses', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AppStatusChip(label: 'Active', status: AppStatusType.active),
                AppStatusChip(label: 'Syncing', status: AppStatusType.syncing),
                AppStatusChip(label: 'Offline', status: AppStatusType.offline),
                AppStatusChip(label: 'Accessible', status: AppStatusType.accessible),
                AppStatusChip(label: 'Error', status: AppStatusType.error),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Syncing'), findsOneWidget);
      expect(find.text('Offline'), findsOneWidget);
      expect(find.text('Accessible'), findsOneWidget);
      expect(find.text('Error'), findsOneWidget);
    });

    testWidgets('AppButton handles loading and disabled states', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AppButton(
                  label: 'Submit',
                  isLoading: true,
                  onPressed: () {},
                ),
                const AppButton(
                  label: 'Disabled',
                  onPressed: null,
                ),
              ],
            ),
          ),
        ),
      );

      // Loading button renders CircularProgressIndicator instead of label
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Disabled'), findsOneWidget);
    });

    testWidgets('AppTextField toggles password visibility', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppTextField(
              label: 'Secret Code',
              isPassword: true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

      // Tap toggle visibility
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('AppCard and AppActionCard respond to taps', (tester) async {
      bool actionCardTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppActionCard(
              title: 'Floor 1 Overview',
              subtitle: '15 nodes recorded',
              icon: Icons.map,
              onTap: () => actionCardTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Floor 1 Overview'), findsOneWidget);
      expect(find.text('15 nodes recorded'), findsOneWidget);

      await tester.tap(find.text('Floor 1 Overview'));
      await tester.pump();
      expect(actionCardTapped, isTrue);
    });

    testWidgets('AppDialogs.showConfirm returns boolean based on user choice', (tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await AppDialogs.showConfirm(
                    context,
                    title: 'Delete Node?',
                    message: 'This will remove the selected waypoint.',
                    confirmLabel: 'Delete',
                    isDestructive: true,
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Node?'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isFalse);

      // Open again and tap Confirm
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });
  });
}
