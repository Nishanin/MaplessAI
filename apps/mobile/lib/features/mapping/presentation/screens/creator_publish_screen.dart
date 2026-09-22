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

/// Publish Confirmation & Submission Screen
/// Owner: Nishant (Phase 3 — Creator Map Publishing)
class CreatorPublishScreen extends ConsumerStatefulWidget {
  const CreatorPublishScreen({super.key});

  @override
  ConsumerState<CreatorPublishScreen> createState() => _CreatorPublishScreenState();
}

class _CreatorPublishScreenState extends ConsumerState<CreatorPublishScreen> {
  bool _simulateFailure = false;
  bool _publishedSuccess = false;

  void _handlePublish() async {
    final creatorNotifier = ref.read(creatorProvider.notifier);
    final result = await creatorNotifier.publishCurrentDraft(
      simulateFailure: _simulateFailure,
    );

    if (mounted) {
      if (result.isSuccess) {
        setState(() => _publishedSuccess = true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Publishing failed.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    if (authState.user != null && authState.user!.role == UserRole.visitor) {
      return AppScaffold(
        title: 'Publish Map',
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
    final draft = creatorState.activeDraft;

    if (draft == null) {
      return AppScaffold(
        title: 'Publish Map',
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.textMuted),
              const SizedBox(height: AppSpacing.md),
              const Text('No map selected for publishing.',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Back to Creator Dashboard',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      );
    }

    final isValid = creatorState.isReadyToPublish;
    final isLoading = creatorState.isLoading;

    if (_publishedSuccess || draft.lifecycleState == MapLifecycleState.published) {
      return AppScaffold(
        title: 'Publish Successful',
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle, size: 56, color: AppColors.success),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Map Published Successfully!',
                  style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${draft.building.name} • ${draft.floor.name}',
                  style: AppTypography.titleMedium.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  variant: AppCardVariant.outlined,
                  borderColor: AppColors.border,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DetailRow(label: 'Draft ID', value: draft.id),
                      const Divider(height: 16),
                      _DetailRow(label: 'Locations', value: '${draft.nodes.length} nodes'),
                      const Divider(height: 16),
                      _DetailRow(label: 'Connections', value: '${draft.edges.length} edges'),
                      const Divider(height: 16),
                      _DetailRow(label: 'Semantic Tags', value: '${draft.metadata.length} entries'),
                      const Divider(height: 16),
                      const _DetailRow(
                        label: 'Storage Backend',
                        value: 'Mock Repository (isMock: true)',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Go to Creator Dashboard',
                  icon: Icons.dashboard_outlined,
                  isFullWidth: true,
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'View Campus Buildings',
                  icon: Icons.business_outlined,
                  variant: AppButtonVariant.outlined,
                  isFullWidth: true,
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, AppRouter.buildings);
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AppScaffold(
      title: 'Publish Indoor Map',
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Details Card
              AppCard(
                variant: AppCardVariant.elevated,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            draft.building.name,
                            style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        AppStatusChip(
                          label: draft.lifecycleState.name.toUpperCase(),
                          status: isValid ? AppStatusType.active : AppStatusType.warning,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Floor: ${draft.floor.name} (Level ${draft.floor.floorNumber})',
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Divider(height: 1),
                    const SizedBox(height: AppSpacing.md),
                    _DetailRow(label: 'Building Category', value: draft.building.category),
                    const SizedBox(height: 8),
                    _DetailRow(label: 'Campus Coordinates', value: '${draft.building.latitude}, ${draft.building.longitude}'),
                    const SizedBox(height: 8),
                    _DetailRow(label: 'Floor Elevation', value: '${draft.floor.elevation}m'),
                    const SizedBox(height: 8),
                    _DetailRow(label: 'Locations Plotted', value: '${draft.nodes.length} nodes'),
                    const SizedBox(height: 8),
                    _DetailRow(label: 'Path Connections', value: '${draft.edges.length} edges'),
                    const SizedBox(height: 8),
                    _DetailRow(label: 'Semantic Metadata', value: '${draft.metadata.length} annotations'),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Validation Status Banner
              if (isValid)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: AppColors.success, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Graph validation passed. The indoor topological model is structurally sound and ready for publication.',
                          style: TextStyle(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 24),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Graph has not passed validation. Please resolve all topological errors in the editor before publishing.',
                          style: TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Back to Editor'),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: AppSpacing.md),

              // Mock Persistence Notice
              AppCard(
                variant: AppCardVariant.outlined,
                borderColor: AppColors.border,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: AppColors.info),
                        SizedBox(width: 8),
                        Text(
                          'Mock Storage Persistence Notice',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Phase 3 UI publishes to the isolated in-memory ICreatorMappingRepository (isMock: true). Cloud/backend persistence and multi-user sync are handled in downstream phases.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Developer Simulation Toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Simulate Server Error (Testing)', style: TextStyle(fontSize: 12)),
                        Switch(
                          value: _simulateFailure,
                          onChanged: (v) => setState(() => _simulateFailure = v),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Error display if any
              if (creatorState.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: AppColors.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          creatorState.errorMessage!,
                          style: const TextStyle(color: AppColors.error, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Publish Actions
              AppButton(
                label: isLoading ? 'Publishing...' : 'Publish Map',
                icon: Icons.cloud_upload_outlined,
                isLoading: isLoading,
                isFullWidth: true,
                onPressed: isValid && !isLoading ? _handlePublish : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Cancel & Return to Preview',
                variant: AppButtonVariant.text,
                isFullWidth: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
