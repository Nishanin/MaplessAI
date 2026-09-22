import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/state/auth_state.dart';
import '../../../../core/state/spatial_state.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_status_chip.dart';

/// User Profile & Account Management Screen
/// Owner: Nishant (Phase 2 — Application Routing)
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppDialogs.showConfirm(
      context,
      title: 'Sign Out',
      message: 'Are you sure you want to end your MapLess AI session?',
      confirmLabel: 'Sign Out',
      isDestructive: true,
      icon: Icons.logout,
    );

    if (confirmed == true && context.mounted) {
      ref.read(authProvider.notifier).logout();
      Navigator.of(context).pushNamedAndRemoveUntil(AppRouter.login, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final spatialState = ref.watch(spatialStateProvider);
    final user = authState.user;

    return AppScaffold(
      title: 'User Profile',
      body: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          children: [
            // User Profile Header Card
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      user != null && user.name.isNotEmpty
                          ? user.name.substring(0, 1).toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    user?.name ?? 'Guest User',
                    style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user?.email ?? 'guest@mapless.local',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppStatusChip(
                    label: user?.role == UserRole.creator ? 'CREATOR ROLE' : 'VISITOR ROLE',
                    status: user?.role == UserRole.creator
                        ? AppStatusType.active
                        : AppStatusType.info,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Active Spatial Session Summary
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active Spatial Context',
                    style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.apartment, color: AppColors.primary),
                    title: Text(
                      spatialState.selectedBuilding?.name ?? 'No building selected',
                      style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Floor: ${spatialState.selectedFloor?.name ?? "None"}',
                      style: AppTypography.bodySmall,
                    ),
                    trailing: TextButton(
                      onPressed: () => Navigator.pushNamed(context, AppRouter.buildings),
                      child: const Text('Change'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Navigation Links
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.settings_outlined, color: AppColors.textPrimary),
                    title: const Text('Application Settings'),
                    subtitle: const Text('Preferences, cache, diagnostics'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pushNamed(context, AppRouter.settings),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.history, color: AppColors.textPrimary),
                    title: const Text('Version & Audit History'),
                    subtitle: const Text('Graph snapshots and change logs'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pushNamed(context, AppRouter.versionHistory),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Sign Out Button
            AppButton(
              label: 'Sign Out',
              icon: Icons.logout,
              variant: AppButtonVariant.danger,
              isFullWidth: true,
              onPressed: () => _handleLogout(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
