import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Reusable floating map controls for indoor canvas navigation
/// Includes zoom in/out, fit-to-screen, floor switcher, and layer toggles.
class MapFloatingControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onResetView;
  final VoidCallback? onToggleLayers;
  final String? currentFloorLabel;
  final VoidCallback? onFloorSelectorTap;

  const MapFloatingControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onResetView,
    this.onToggleLayers,
    this.currentFloorLabel,
    this.onFloorSelectorTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Floor selector pill (if provided)
        if (currentFloorLabel != null) ...[
          Material(
            color: AppColors.surface,
            elevation: AppSpacing.elevationMedium,
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            child: InkWell(
              onTap: onFloorSelectorTap,
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.layers, size: 18, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      currentFloorLabel!,
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (onFloorSelectorTap != null) ...[
                      const SizedBox(width: AppSpacing.xs),
                      const Icon(Icons.arrow_drop_down, size: 18, color: AppColors.primary),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],

        // Floating Control Box (Zoom + Reset)
        Material(
          color: AppColors.surface,
          elevation: AppSpacing.elevationMedium,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.add, color: AppColors.textPrimary),
                tooltip: 'Zoom In',
                onPressed: onZoomIn,
              ),
              const Divider(height: 1, color: AppColors.border),
              IconButton(
                icon: const Icon(Icons.remove, color: AppColors.textPrimary),
                tooltip: 'Zoom Out',
                onPressed: onZoomOut,
              ),
              const Divider(height: 1, color: AppColors.border),
              IconButton(
                icon: const Icon(Icons.center_focus_strong, color: AppColors.primary),
                tooltip: 'Reset View',
                onPressed: onResetView,
              ),
              if (onToggleLayers != null) ...[
                const Divider(height: 1, color: AppColors.border),
                IconButton(
                  icon: const Icon(Icons.layers_outlined, color: AppColors.textSecondary),
                  tooltip: 'Toggle Layers',
                  onPressed: onToggleLayers,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
