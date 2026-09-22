import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/state/auth_state.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_status_chip.dart';
import '../../domain/map_draft_model.dart';
import '../../state/creator_controller.dart';
import '../widgets/indoor_canvas.dart';
import '../widgets/validation_summary_card.dart';

/// Read-Only Map Preview & Review Screen
/// Owner: Nishant (Phase 3 — Creator Map Preview)
class CreatorPreviewScreen extends ConsumerWidget {
  const CreatorPreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    if (authState.user != null && authState.user!.role == UserRole.visitor) {
      return AppScaffold(
        title: 'Map Preview',
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 56, color: AppColors.textMuted),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Creator Access Only',
                  style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'This workspace is reserved for authorized map creators and facility staff. Visitors can explore published maps and navigate routes.',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Return to Visitor Navigation',
                  icon: Icons.explore,
                  onPressed: () => Navigator.of(context).pushReplacementNamed(AppRouter.home),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final creatorState = ref.watch(creatorProvider);
    final creatorNotifier = ref.read(creatorProvider.notifier);
    final draft = creatorState.activeDraft;

    if (draft == null) {
      return AppScaffold(
        title: 'Map Preview',
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.preview_outlined, size: 64, color: AppColors.textMuted),
              const SizedBox(height: AppSpacing.md),
              const Text('No active map draft to preview',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Go to Creator Dashboard',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      );
    }

    final validationResult = creatorState.validationResult;
    final totalNodes = draft.nodes.length;
    final totalEdges = draft.edges.length;
    final blockedEdges = draft.edges.where((e) => e.blocked).length;
    final accessibleEdges = totalEdges - blockedEdges;
    final metadataCount = draft.metadata.length;

    final AppStatusType lifecycleStatusType = switch (draft.lifecycleState) {
      MapLifecycleState.draft => AppStatusType.info,
      MapLifecycleState.validated => AppStatusType.active,
      MapLifecycleState.published => AppStatusType.active,
      MapLifecycleState.failed => AppStatusType.error,
    };

    return AppScaffold(
      title: 'Map Preview',
      actions: [
        IconButton(
          tooltip: 'Re-validate Map',
          icon: const Icon(Icons.verified_outlined, color: AppColors.primary),
          onPressed: () => creatorNotifier.validateCurrentDraft(),
        ),
      ],
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Summary Card
              AppCard(
                variant: AppCardVariant.elevated,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${draft.building.name} • ${draft.floor.name}',
                                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Draft ID: ${draft.id} • Elevation: ${draft.floor.elevation}m',
                                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        AppStatusChip(
                          label: draft.lifecycleState.name.toUpperCase(),
                          status: lifecycleStatusType,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Mock Persistence Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.blueGrey.shade200),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.storage_outlined, size: 14, color: AppColors.textSecondary),
                          SizedBox(width: 6),
                          Text(
                            'Mock Persistence: Local in-memory repository (isMock: true)',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Metrics Grid
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: 'Locations',
                      value: '$totalNodes',
                      icon: Icons.place_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _MetricTile(
                      label: 'Edges (Walkable)',
                      value: '$accessibleEdges',
                      icon: Icons.alt_route,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _MetricTile(
                      label: 'Blocked Edges',
                      value: '$blockedEdges',
                      icon: Icons.block,
                      color: blockedEdges > 0 ? AppColors.warning : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _MetricTile(
                      label: 'Semantics',
                      value: '$metadataCount',
                      icon: Icons.label_outline,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),

              // 2D Read-Only Canvas Section
              const Text(
                'Graph Visual Layout',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.xs),
              Container(
                height: 280,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: totalNodes == 0
                      ? const Center(
                          child: Text(
                            'No locations plotted yet',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        )
                      : IndoorCanvas(
                          nodes: draft.nodes,
                          edges: draft.edges,
                        ),
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // Canvas Legend
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _LegendItem(color: AppColors.primary, label: 'Location Node'),
                  _LegendItem(color: AppColors.textSecondary, label: 'Walkway Edge'),
                  _LegendItem(color: AppColors.error, label: 'Blocked / Hazard Edge'),
                ],
              ),

              const SizedBox(height: AppSpacing.md),

              // Validation Card
              const Text(
                'Validation Status',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.xs),
              if (validationResult != null)
                ValidationSummaryCard(
                  result: validationResult,
                  onRevalidate: () => creatorNotifier.validateCurrentDraft(),
                )
              else
                AppCard(
                  variant: AppCardVariant.outlined,
                  borderColor: AppColors.border,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.info, size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Graph has not been validated yet. Run validation to verify topology before publishing.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => creatorNotifier.validateCurrentDraft(),
                        child: const Text('Validate'),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: AppSpacing.md),

              // Semantic Annotations List
              if (draft.metadata.isNotEmpty) ...[
                const Text(
                  'Semantic Annotations',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.xs),
                ...draft.metadata.map((meta) {
                  final node = draft.nodes.where((n) => n.id == meta.entityId).firstOrNull;
                  final label = node?.name ?? meta.entityId;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.sell_outlined, color: AppColors.accent),
                      title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (meta.tags.isNotEmpty)
                            Text('Tags: ${meta.tags.join(', ')}', style: const TextStyle(fontSize: 12)),
                          if (meta.aliases.isNotEmpty)
                            Text('Aliases: ${meta.aliases.join(', ')}', style: const TextStyle(fontSize: 12)),
                          if (meta.department != null && meta.department!.isNotEmpty)
                            Text('Dept: ${meta.department}', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      trailing: meta.operationalHours != null && meta.operationalHours!.isNotEmpty
                          ? Chip(
                              label: Text(meta.operationalHours!, style: const TextStyle(fontSize: 10)),
                              padding: EdgeInsets.zero,
                            )
                          : null,
                    ),
                  );
                }),
                const SizedBox(height: AppSpacing.md),
              ],

              // Navigation & Publish Actions
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Return to Editor',
                      icon: Icons.edit_outlined,
                      variant: AppButtonVariant.outlined,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppButton(
                      label: 'Proceed to Publish',
                      icon: Icons.publish_outlined,
                      variant: AppButtonVariant.primary,
                      onPressed: () {
                        // Ensure graph is validated first
                        final res = creatorNotifier.validateCurrentDraft();
                        if (res.isValid) {
                          Navigator.pushNamed(context, AppRouter.creatorPublish);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Cannot publish with validation errors (${res.errorCount} errors). Please resolve them in Editor.',
                              ),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
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

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}
