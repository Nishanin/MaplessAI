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

/// Dedicated Visitor Exploration & Route Selection Screen
/// Owner: Nishant (Phase 2 — Application Routing)
class VisitorScreen extends ConsumerWidget {
  const VisitorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spatialState = ref.watch(spatialStateProvider);
    final spatialNotifier = ref.read(spatialStateProvider.notifier);

    final building = spatialState.selectedBuilding;
    final floor = spatialState.selectedFloor;
    final nodes = spatialState.availableNodes;
    final currentLocation = spatialState.selectedCurrentLocation;
    final destination = spatialState.selectedDestination;

    final validFloorId = spatialState.availableFloors.any((f) => f.id == floor?.id)
        ? floor?.id
        : (spatialState.availableFloors.isNotEmpty ? spatialState.availableFloors.first.id : null);

    final validCurrentLocationId = nodes.any((n) => n.id == currentLocation?.id)
        ? currentLocation?.id
        : null;

    final validDestinationId = nodes.any((n) => n.id == destination?.id)
        ? destination?.id
        : null;

    return AppScaffold(
      title: 'Visitor Exploration',
      body: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Current Building & Floor Summary Card
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Active Campus Location',
                        style: AppTypography.labelSmall.copyWith(color: AppColors.textMuted),
                      ),
                      TextButton.icon(
                        onPressed: () => Navigator.pushNamed(context, AppRouter.buildings),
                        icon: const Icon(Icons.swap_horiz, size: 16),
                        label: const Text('Switch Building'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    building?.name ?? 'No Building Selected',
                    style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    building?.address ?? 'Select a campus building to begin indoor exploration.',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Floor Selector Dropdown
                  if (spatialState.availableFloors.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.layers, size: 20, color: AppColors.primary),
                        const SizedBox(width: AppSpacing.sm),
                        const Text('Floor: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: validFloorId,
                            items: spatialState.availableFloors.map((f) {
                              return DropdownMenuItem(
                                value: f.id,
                                child: Text(f.name),
                              );
                            }).toList(),
                            onChanged: (id) {
                              if (id != null) {
                                final selected = spatialState.availableFloors
                                    .firstWhere((f) => f.id == id);
                                spatialNotifier.selectFloor(selected);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Route Points Selector Card
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Wayfinding Points',
                        style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        tooltip: 'Swap start and destination',
                        icon: const Icon(Icons.swap_vert, color: AppColors.primary),
                        onPressed: spatialNotifier.swapLocations,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Current Location Selector
                  Row(
                    children: [
                      const Icon(Icons.my_location, color: Colors.green, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          hint: const Text('Select Current Location'),
                          value: validCurrentLocationId,
                          items: nodes.map((n) {
                            return DropdownMenuItem(
                              value: n.id,
                              child: Text('${n.name} (${n.category})'),
                            );
                          }).toList(),
                          onChanged: spatialNotifier.setCurrentLocationById,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: AppSpacing.md),

                  // Destination Selector
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.red, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          hint: const Text('Select Destination'),
                          value: validDestinationId,
                          items: nodes.map((n) {
                            return DropdownMenuItem(
                              value: n.id,
                              child: Text('${n.name} (${n.category})'),
                            );
                          }).toList(),
                          onChanged: spatialNotifier.setDestinationById,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Quick POI Suggestions
            if (nodes.isNotEmpty) ...[
              Text(
                'Quick Destinations on this floor',
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: nodes.map((n) {
                  final isTarget = destination?.id == n.id;
                  return ActionChip(
                    avatar: Icon(
                      n.category == 'entrance'
                          ? Icons.door_front_door
                          : n.category == 'elevator'
                              ? Icons.elevator
                              : n.category == 'stairs'
                                  ? Icons.stairs
                                  : Icons.place,
                      size: 16,
                      color: isTarget ? Colors.white : AppColors.primary,
                    ),
                    label: Text(n.name),
                    backgroundColor: isTarget ? AppColors.primary : AppColors.surface,
                    labelStyle: TextStyle(
                      color: isTarget ? Colors.white : AppColors.textPrimary,
                      fontSize: 12,
                    ),
                    onPressed: () => spatialNotifier.setDestination(n),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            // Action Buttons
            AppButton(
              label: 'Get Turn-by-Turn Directions',
              icon: Icons.alt_route,
              isFullWidth: true,
              onPressed: () => Navigator.pushNamed(context, AppRouter.navigation),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Open Interactive 2D Map',
              icon: Icons.map,
              variant: AppButtonVariant.outlined,
              isFullWidth: true,
              onPressed: () => Navigator.pushNamed(context, AppRouter.map),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Ask AI Campus Assistant',
              icon: Icons.smart_toy_outlined,
              variant: AppButtonVariant.text,
              isFullWidth: true,
              onPressed: () => Navigator.pushNamed(context, AppRouter.aiAssistant),
            ),
          ],
        ),
      ),
    );
  }
}
