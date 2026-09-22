import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/state/spatial_state.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_status_chip.dart';
import '../widgets/multi_floor_visualizer.dart';

/// Building Overview & Multi-Floor Visualization Screen
/// Owner: Nishant (Phase 5 — Building + Multi-Floor Visualization)
class BuildingOverviewScreen extends ConsumerWidget {
  const BuildingOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spatialState = ref.watch(spatialStateProvider);
    final spatialNotifier = ref.read(spatialStateProvider.notifier);

    final building = spatialState.selectedBuilding;
    final floors = spatialState.availableFloors;
    final selectedFloor = spatialState.selectedFloor;
    final nodes = spatialState.availableNodes;

    return AppScaffold(
      title: building?.name ?? 'Building Overview',
      actions: [
        IconButton(
          tooltip: 'Switch Building',
          icon: const Icon(Icons.apartment_outlined),
          onPressed: () => Navigator.pushNamed(context, AppRouter.buildings),
        ),
      ],
      body: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Building Header Card
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primarySubtle,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                        child: const Icon(
                          Icons.apartment,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    building?.name ?? 'Select a Building',
                                    style: AppTypography.titleLarge.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                AppStatusChip(
                                  label: (building?.category ?? 'Academic').toUpperCase(),
                                  status: AppStatusType.info,
                                  isCompact: true,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              building?.address ?? 'No address registered',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Divider(height: 1),
                  const SizedBox(height: AppSpacing.sm),

                  // Building Metrics Strip
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _MetricItem(
                        icon: Icons.layers,
                        label: 'Total Floors',
                        value: '${floors.length}',
                        color: AppColors.primary,
                      ),
                      _MetricItem(
                        icon: Icons.place,
                        label: 'Active Level POIs',
                        value: '${nodes.length}',
                        color: AppColors.secondary,
                      ),
                      _MetricItem(
                        icon: Icons.accessible,
                        label: 'Accessibility',
                        value: 'Verified',
                        color: AppColors.success,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Multi-Floor Visualizer Section Heading
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Multi-Floor Building Stack',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  'Tap level to view map',
                  style: AppTypography.labelSmall.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Stacked Multi-Floor Visualizer Card
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: MultiFloorVisualizer(
                floors: floors,
                selectedFloor: selectedFloor,
                allNodes: nodes,
                onFloorSelected: (floor) {
                  spatialNotifier.selectFloor(floor);
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Selected Floor Active Details Card
            if (selectedFloor != null) ...[
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.map, size: 20, color: AppColors.primary),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Active Level: ${selectedFloor.name}',
                            style: AppTypography.titleSmall.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primarySubtle,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          ),
                          child: Text(
                            'Elevation ${selectedFloor.elevation >= 0 ? "+" : ""}${selectedFloor.elevation.toStringAsFixed(1)}m',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Explore topological nodes, corridors, stairwells, and emergency exits on this floor in the interactive 2D canvas.',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: 'Open 2D Indoor Map',
                            icon: Icons.open_in_full,
                            onPressed: () {
                              Navigator.pushNamed(context, AppRouter.map);
                            },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        IconButton(
                          tooltip: 'Explore Visitor Guidance',
                          icon: const Icon(Icons.explore, color: AppColors.primary),
                          onPressed: () {
                            Navigator.pushNamed(context, AppRouter.visitor);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}
