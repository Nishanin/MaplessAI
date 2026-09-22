import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/models/floor_model.dart';
import '../../../../core/models/node_model.dart';
import '../../../../core/theme/app_typography.dart';

/// Multi-Floor Building Stack Visualization Widget
/// Owner: Nishant (Phase 5 — Building + Multi-Floor Visualization)
class MultiFloorVisualizer extends StatelessWidget {
  final List<FloorModel> floors;
  final FloorModel? selectedFloor;
  final ValueChanged<FloorModel> onFloorSelected;
  final List<NodeModel> allNodes;
  final bool showConnectorColumn;

  const MultiFloorVisualizer({
    super.key,
    required this.floors,
    required this.selectedFloor,
    required this.onFloorSelected,
    this.allNodes = const [],
    this.showConnectorColumn = true,
  });

  @override
  Widget build(BuildContext context) {
    if (floors.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Text('No floor data available for this building.'),
        ),
      );
    }

    // Sort floors in descending order so highest floor is displayed at the top of the stack
    final sortedFloors = List<FloorModel>.from(floors)
      ..sort((a, b) => b.floorNumber.compareTo(a.floorNumber));

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 380;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vertical Shafts / Transportation Column (Elevators & Stairs indicators)
            if (showConnectorColumn) ...[
              _VerticalTransportColumn(
                floorCount: sortedFloors.length,
                isNarrow: isNarrow,
              ),
              const SizedBox(width: AppSpacing.sm),
            ],

            // Stacked Floor Cards
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < sortedFloors.length; i++) ...[
                    _FloorPlateCard(
                      floor: sortedFloors[i],
                      isSelected: selectedFloor?.id == sortedFloors[i].id,
                      onTap: () => onFloorSelected(sortedFloors[i]),
                      floorNodes: allNodes
                          .where((n) => n.floorId == sortedFloors[i].id)
                          .toList(),
                      isTop: i == 0,
                      isBottom: i == sortedFloors.length - 1,
                      isNarrow: isNarrow,
                    ),
                    if (i < sortedFloors.length - 1)
                      const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Architectural vertical transport column showing elevator and stair shafts
class _VerticalTransportColumn extends StatelessWidget {
  final int floorCount;
  final bool isNarrow;

  const _VerticalTransportColumn({
    required this.floorCount,
    required this.isNarrow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isNarrow ? 36 : 44,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Elevator shaft glyph
          Tooltip(
            message: 'Continuous Elevator Shaft',
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.nodeElevator.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.elevator,
                color: AppColors.nodeElevator,
                size: 16,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          // Connector shaft dashed vertical bar
          Container(
            width: 3,
            height: (floorCount * 65.0).clamp(60.0, 240.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.nodeElevator,
                  AppColors.primary,
                  AppColors.nodeStairs,
                ],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          // Stairs shaft glyph
          Tooltip(
            message: 'Continuous Stairway Shaft',
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.nodeStairs.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.stairs,
                color: AppColors.nodeStairs,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Interactive Floor Plate Card in the Multi-Floor Stack
class _FloorPlateCard extends StatelessWidget {
  final FloorModel floor;
  final bool isSelected;
  final VoidCallback onTap;
  final List<NodeModel> floorNodes;
  final bool isTop;
  final bool isBottom;
  final bool isNarrow;

  const _FloorPlateCard({
    required this.floor,
    required this.isSelected,
    required this.onTap,
    required this.floorNodes,
    required this.isTop,
    required this.isBottom,
    required this.isNarrow,
  });

  @override
  Widget build(BuildContext context) {
    final elevatorCount = floorNodes.where((n) => n.category == 'elevator').length;
    final stairCount = floorNodes.where((n) => n.category == 'stairs').length;
    final exitCount = floorNodes.where((n) => n.category == 'emergency_exit').length;
    final roomCount = floorNodes.where((n) => n.category == 'room' || n.category == 'laboratory').length;

    final floorLabel = floor.floorNumber <= 0 || (floor.floorNumber == 1 && floor.name.toLowerCase().contains('ground'))
        ? 'G'
        : 'F${floor.floorNumber}';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primarySubtle : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: isSelected ? 2.0 : 1.0,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header: Floor tag, Name, Elevation, and Selection Badge
                Row(
                  children: [
                    // Floor Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.secondarySubtle,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: Text(
                        floorLabel,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.secondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // Floor Name
                    Expanded(
                      child: Text(
                        floor.name,
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? AppColors.primary : AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    // Elevation Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        '${floor.elevation > 0 ? "+" : ""}${floor.elevation.toStringAsFixed(1)}m',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.check_circle, size: 16, color: AppColors.primary),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xs + 2),

                // Facilities & Features Pills Row
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _FeaturePill(
                      icon: Icons.elevator,
                      label: elevatorCount > 0 ? '$elevatorCount' : '0',
                      color: AppColors.nodeElevator,
                      tooltip: 'Elevators',
                    ),
                    _FeaturePill(
                      icon: Icons.stairs,
                      label: stairCount > 0 ? '$stairCount' : '0',
                      color: AppColors.nodeStairs,
                      tooltip: 'Stairs',
                    ),
                    _FeaturePill(
                      icon: Icons.exit_to_app,
                      label: exitCount > 0 ? '$exitCount' : '0',
                      color: AppColors.nodeExit,
                      tooltip: 'Emergency Exits',
                    ),
                    if (roomCount > 0)
                      _FeaturePill(
                        icon: Icons.meeting_room,
                        label: '$roomCount',
                        color: AppColors.primary,
                        tooltip: 'Rooms / POIs',
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

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String tooltip;

  const _FeaturePill({
    required this.icon,
    required this.label,
    required this.color,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
