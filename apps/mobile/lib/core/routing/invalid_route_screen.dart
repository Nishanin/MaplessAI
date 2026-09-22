import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import 'app_router.dart';

/// Screen displayed when an invalid or unknown route is requested
/// Owner: Nishant (Phase 2 — Application Routing)
class InvalidRouteScreen extends StatelessWidget {
  final String? routeName;

  const InvalidRouteScreen({
    super.key,
    this.routeName,
  });

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Route Not Found'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppSpacing.screenPadding,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Error Icon Container
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.errorSubtle,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.explore_off_outlined,
                    size: 44,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Error Heading
                Text(
                  '404 — Invalid Route',
                  style: AppTypography.headlineMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),

                // Subtitle
                Text(
                  'The requested destination does not exist or has been moved.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),

                // Diagnostics Card
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline, size: 16, color: AppColors.textMuted),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            'Routing Diagnostics',
                            style: AppTypography.labelSmall.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Requested Route: ${routeName ?? "null / unknown"}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Action Buttons
                Row(
                  children: [
                    if (canPop) ...[
                      Expanded(
                        child: AppButton(
                          label: 'Go Back',
                          variant: AppButtonVariant.outlined,
                          icon: Icons.arrow_back,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                    ],
                    Expanded(
                      child: AppButton(
                        label: 'Return to Home',
                        icon: Icons.home,
                        onPressed: () {
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            AppRouter.home,
                            (route) => false,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
