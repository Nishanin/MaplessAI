import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/state/spatial_state.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_scaffold.dart';

/// Application Settings & Preferences Screen
/// Owner: Nishant (Phase 2 — Application Routing)
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _offlineCaching = true;
  bool _hapticFeedback = true;
  bool _preferAccessibleRoutes = false;
  bool _highContrastGrid = false;

  void _resetSpatialState() {
    ref.read(spatialStateProvider.notifier).reset();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Spatial selections and state successfully reset.'),
        backgroundColor: AppColors.primary,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spatialState = ref.watch(spatialStateProvider);

    return AppScaffold(
      title: 'Settings',
      body: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section: Navigation & Mapping Preferences
            Text(
              'Navigation & Mapping Preferences',
              style: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Offline Map Caching'),
                    subtitle: const Text('Store downloaded floor graphs locally'),
                    value: _offlineCaching,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) => setState(() => _offlineCaching = val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Haptic Feedback'),
                    subtitle: const Text('Vibrate on node tap and route checkpoint'),
                    value: _hapticFeedback,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) => setState(() => _hapticFeedback = val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Prefer Accessible Routes'),
                    subtitle: const Text('Avoid stairs; favor elevators and ramps'),
                    value: _preferAccessibleRoutes,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) => setState(() => _preferAccessibleRoutes = val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('High Contrast Grid'),
                    subtitle: const Text('Enhanced indoor canvas visibility'),
                    value: _highContrastGrid,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) => setState(() => _highContrastGrid = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Section: Global State & Diagnostics
            Text(
              'Global UI State & Diagnostics',
              style: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Active Building:', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        spatialState.selectedBuilding?.name ?? 'None',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Active Floor:', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        spatialState.selectedFloor?.name ?? 'None',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Current Location:', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        spatialState.selectedCurrentLocation?.name ?? 'None',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Destination:', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        spatialState.selectedDestination?.name ?? 'None',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Reset Spatial State',
                    icon: Icons.restart_alt,
                    variant: AppButtonVariant.outlined,
                    isFullWidth: true,
                    onPressed: _resetSpatialState,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Section: Application Information
            Text(
              'System Information',
              style: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Application Version', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('1.0.0+1 (V1)', style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Architecture', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('Riverpod + Central Router', style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Branch', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('feature/nishant-mapping-ui', style: TextStyle(color: AppColors.primary)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
