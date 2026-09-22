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
import '../../domain/map_draft_model.dart';
import '../../services/sensor_provider.dart';
import '../../state/creator_controller.dart';
import '../../state/mapping_controller.dart';
import '../widgets/create_building_dialog.dart';
import '../widgets/create_floor_dialog.dart';

/// Creator Dashboard and Session Launcher
/// Owner: Nishant (Phase 3 — Creator Mapping Workflow)
class CreatorMappingScreen extends ConsumerWidget {
  const CreatorMappingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creatorState = ref.watch(creatorProvider);
    final creatorNotifier = ref.read(creatorProvider.notifier);
    final spatialState = ref.watch(spatialStateProvider);

    // Sensor state for Phase 4 stubs compatibility & live engine
    final sensorState = ref.watch(mappingProvider);
    final sensorController = ref.read(mappingProvider.notifier);
    final liveSensor = ref.watch(sensorStateProvider);
    final liveSensorNotifier = ref.read(sensorStateProvider.notifier);

    final activeBuilding = spatialState.selectedBuilding ??
        (spatialState.availableBuildings.isNotEmpty ? spatialState.availableBuildings.first : null);
    final availableFloors = spatialState.availableFloors;
    final activeFloor = spatialState.selectedFloor ??
        (availableFloors.isNotEmpty ? availableFloors.first : null);

    return AppScaffold(
      title: 'Creator Mapping Hub',
      actions: [
        IconButton(
          tooltip: 'Refresh Projects',
          icon: const Icon(Icons.refresh),
          onPressed: () => creatorNotifier.loadProjects(),
        ),
      ],
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dashboard Welcome Banner
              AppCard(
                variant: AppCardVariant.elevated,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.architecture, color: AppColors.primary, size: 28),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Indoor Map Creator Hub',
                                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Author, plot, connect, and validate indoor topological maps.',
                                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Divider(height: 1),
                    const SizedBox(height: AppSpacing.md),

                    // Active Campus Selection Summary
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Active Target:',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                              Text(
                                activeBuilding != null
                                    ? '${activeBuilding.name} • ${activeFloor?.name ?? "No floor selected"}'
                                    : 'No building selected',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.add_business, size: 16),
                              label: const Text('Building', style: TextStyle(fontSize: 12)),
                              onPressed: () async {
                                final created = await CreateBuildingDialog.show(context);
                                if (created != null) {
                                  creatorNotifier.createBuilding(
                                    name: created.name,
                                    id: created.id,
                                    address: created.address,
                                    category: created.category,
                                    latitude: created.latitude,
                                    longitude: created.longitude,
                                  );
                                }
                              },
                            ),
                            if (activeBuilding != null)
                              TextButton.icon(
                                icon: const Icon(Icons.layers, size: 16),
                                label: const Text('Floor', style: TextStyle(fontSize: 12)),
                                onPressed: () async {
                                  final created = await CreateFloorDialog.show(
                                    context,
                                    buildingId: activeBuilding.id,
                                  );
                                  if (created != null) {
                                    creatorNotifier.createFloor(
                                      buildingId: activeBuilding.id,
                                      name: created.name,
                                      floorNumber: created.floorNumber,
                                      elevation: created.elevation,
                                    );
                                  }
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Launch Editor Button
                    AppButton(
                      label: creatorState.hasActiveDraft
                          ? 'Resume Active Editor Session'
                          : 'Start New Mapping Session',
                      icon: Icons.edit_road,
                      isFullWidth: true,
                      onPressed: () {
                        if (creatorState.hasActiveDraft) {
                          Navigator.pushNamed(context, AppRouter.creatorEditor);
                        } else if (activeBuilding != null && activeFloor != null) {
                          creatorNotifier.startNewSession(
                            building: activeBuilding,
                            floor: activeFloor,
                          );
                          Navigator.pushNamed(context, AppRouter.creatorEditor);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please select or create a building and floor first.'),
                              backgroundColor: AppColors.warning,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Overview Counters
              Row(
                children: [
                  Expanded(
                    child: _StatusCounter(
                      count: creatorState.savedDrafts.length,
                      label: 'Saved Drafts',
                      icon: Icons.drafts_outlined,
                      color: AppColors.info,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _StatusCounter(
                      count: creatorState.publishedMaps.length,
                      label: 'Published Maps',
                      icon: Icons.check_circle_outline,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _StatusCounter(
                      count: spatialState.availableBuildings.length,
                      label: 'Campus Buildings',
                      icon: Icons.business,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // Section: Saved Drafts
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Saved Draft Maps (${creatorState.savedDrafts.length})',
                    style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (creatorState.hasActiveDraft)
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, AppRouter.creatorEditor),
                      child: const Text('Open Current Draft'),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),

              if (creatorState.savedDrafts.isEmpty)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Center(
                    child: Text(
                      'No saved draft sessions. Tap "Start New Mapping Session" above to begin.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ),
                )
              else
                ...creatorState.savedDrafts.map((draft) {
                  final isCurrentActive = creatorState.activeDraft?.id == draft.id;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isCurrentActive ? AppColors.primary : AppColors.border,
                        width: isCurrentActive ? 1.5 : 1.0,
                      ),
                    ),
                    child: ListTile(
                      leading: Icon(
                        isCurrentActive ? Icons.edit_location : Icons.map_outlined,
                        color: isCurrentActive ? AppColors.primary : AppColors.textSecondary,
                      ),
                      title: Text(
                        '${draft.building.name} • ${draft.floor.name}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Text(
                        '${draft.nodes.length} nodes • ${draft.edges.length} edges • ${draft.metadata.length} tags',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppStatusChip(
                            label: draft.lifecycleState.name.toUpperCase(),
                            status: draft.lifecycleState == MapLifecycleState.validated
                                ? AppStatusType.active
                                : AppStatusType.info,
                            isCompact: true,
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_ios, size: 14),
                            tooltip: 'Resume Draft',
                            onPressed: () {
                              creatorNotifier.resumeDraft(draft);
                              Navigator.pushNamed(context, AppRouter.creatorEditor);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                            tooltip: 'Delete Draft',
                            onPressed: () => creatorNotifier.deleteDraftById(draft.id),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

              const SizedBox(height: AppSpacing.lg),

              // Section: Published Maps
              Text(
                'Published Campus Maps (${creatorState.publishedMaps.length})',
                style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.xs),

              if (creatorState.publishedMaps.isEmpty)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Center(
                    child: Text(
                      'No maps published yet. Validate and publish a draft to make it live.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ),
                )
              else
                ...creatorState.publishedMaps.map((pub) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.verified, color: AppColors.success),
                      title: Text(
                        '${pub.building.name} • ${pub.floor.name}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Text(
                        'Published Map ID: ${pub.id} • ${pub.nodes.length} nodes • ${pub.edges.length} edges',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      trailing: const AppStatusChip(
                        label: 'PUBLISHED',
                        status: AppStatusType.active,
                        isCompact: true,
                      ),
                    ),
                  );
                }),

              const SizedBox(height: AppSpacing.xl),

              // Phase 4 Sensor Engine (PDR & Orientation) Preview Card
              Card(
                color: Colors.blueGrey.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.blueGrey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.sensors, color: AppColors.textSecondary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Phase 4 Sensor Engine (PDR & Orientation)',
                              style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Live sensor fusion is active for creator-assisted indoor mapping. Manual coordinate authoring remains available when sensor tracking is unavailable.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: _SensorMiniTile(
                              title: 'Step Counter',
                              value: '${liveSensor.stepCount > 0 ? liveSensor.stepCount : sensorState.recordedSteps} steps',
                              icon: Icons.directions_walk,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _SensorMiniTile(
                              title: 'Compass Heading',
                              value: '${liveSensor.heading.toStringAsFixed(1)}° (${liveSensor.calibratedHeading.toStringAsFixed(1)}° rel)',
                              icon: Icons.explore,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _SensorMiniTile(
                              title: 'Relative Coords',
                              value: 'X: ${liveSensor.x.toStringAsFixed(2)}m, Y: ${liveSensor.y.toStringAsFixed(2)}m',
                              icon: Icons.my_location,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _SensorMiniTile(
                              title: 'Est. Distance',
                              value: '${liveSensor.distance.toStringAsFixed(2)} m',
                              icon: Icons.straighten,
                            ),
                          ),
                        ],
                      ),
                      if (liveSensor.errorMessage != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber.shade900),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  liveSensor.errorMessage!,
                                  style: TextStyle(fontSize: 11, color: Colors.amber.shade900, height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      // Walkthrough & Calibration Controls (Responsive Stacking)
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isCompact = constraints.maxWidth < 380;
                          final isWalking = liveSensor.isRunning || sensorState.isRecordingWalkthrough;

                          final startStopButton = OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onPressed: () {
                              if (isWalking) {
                                liveSensorNotifier.stop();
                                sensorController.stopWalkthrough();
                              } else {
                                liveSensorNotifier.start();
                                sensorController.startWalkthrough();
                              }
                            },
                            icon: Icon(
                              isWalking ? Icons.stop : Icons.play_arrow,
                              size: 16,
                              color: isWalking ? Colors.red : AppColors.primary,
                            ),
                            label: Text(
                              isWalking ? 'Stop Walkthrough' : 'Start Walkthrough',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: isWalking ? Colors.red : AppColors.primary,
                              ),
                            ),
                          );

                          final calibrateButton = OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                            ),
                            onPressed: () => liveSensorNotifier.calibrate(),
                            icon: const Icon(Icons.tune, size: 14),
                            label: const Text(
                              'Zero Heading (0°)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11),
                            ),
                          );

                          final resetButton = OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                            ),
                            onPressed: () => liveSensorNotifier.reset(),
                            icon: const Icon(Icons.refresh, size: 14),
                            label: const Text(
                              'Reset Origin',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11),
                            ),
                          );

                          if (isCompact) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                startStopButton,
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(child: calibrateButton),
                                    const SizedBox(width: 8),
                                    Expanded(child: resetButton),
                                  ],
                                ),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(flex: 3, child: startStopButton),
                              const SizedBox(width: 8),
                              Expanded(flex: 2, child: calibrateButton),
                              const SizedBox(width: 8),
                              Expanded(flex: 2, child: resetButton),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Relative dead-reckoning for creator walkthroughs. Not survey-grade or GPS replacement. Manual coordinate authoring remains fully functional.',
                        style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCounter extends StatelessWidget {
  final int count;
  final String label;
  final IconData icon;
  final Color color;

  const _StatusCounter({
    required this.count,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SensorMiniTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _SensorMiniTile({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
