import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_status_chip.dart';
import '../../domain/map_validation_service.dart';

/// Card summarizing map graph validation results
/// Owner: Nishant (Phase 3 — Creator Validation UI)
class ValidationSummaryCard extends StatelessWidget {
  final ValidationResult result;
  final VoidCallback? onRevalidate;

  const ValidationSummaryCard({
    super.key,
    required this.result,
    this.onRevalidate,
  });

  @override
  Widget build(BuildContext context) {
    final hasErrors = result.errors.isNotEmpty;

    return AppCard(
      borderColor: hasErrors ? AppColors.error : AppColors.success,
      variant: AppCardVariant.outlined,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    hasErrors ? Icons.cancel : Icons.check_circle,
                    color: hasErrors ? AppColors.error : AppColors.success,
                    size: 24,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    hasErrors ? 'Validation Failed' : 'Graph Validated',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: hasErrors ? AppColors.error : AppColors.success,
                    ),
                  ),
                ],
              ),
              AppStatusChip(
                label: hasErrors
                    ? '${result.errors.length} ERRORS'
                    : (result.warnings.isNotEmpty
                        ? '${result.warnings.length} WARNINGS'
                        : 'READY'),
                status: hasErrors
                    ? AppStatusType.error
                    : (result.warnings.isNotEmpty
                        ? AppStatusType.warning
                        : AppStatusType.active),
                isCompact: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            hasErrors
                ? 'Resolve all critical errors before you can preview or publish this map.'
                : 'Topological rules and coordinate contracts conform to MapLess standards.',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          if (result.issues.isNotEmpty) ...[
            const Divider(height: AppSpacing.lg),
            ...result.issues.map((issue) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      issue.isError ? Icons.error_outline : Icons.warning_amber_rounded,
                      size: 18,
                      color: issue.isError ? AppColors.error : AppColors.warning,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
                          children: [
                            TextSpan(
                              text: issue.isError ? '[Error] ' : '[Warning] ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: issue.isError ? AppColors.error : AppColors.warning,
                              ),
                            ),
                            TextSpan(text: issue.message),
                            if (issue.entityId != null)
                              TextSpan(
                                text: ' (ID: ${issue.entityId})',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
