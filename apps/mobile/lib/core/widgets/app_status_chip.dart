import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../theme/app_typography.dart';

enum AppStatusType {
  active,
  syncing,
  offline,
  draft,
  error,
  accessible,
  warning,
  info,
}

/// Reusable status chip indicator with semantic color tokens
class AppStatusChip extends StatelessWidget {
  final String label;
  final AppStatusType status;
  final bool showDot;
  final bool isCompact;

  const AppStatusChip({
    super.key,
    required this.label,
    required this.status,
    this.showDot = true,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, Color dot) = switch (status) {
      AppStatusType.active => (AppColors.successSubtle, AppColors.success, AppColors.success),
      AppStatusType.syncing => (AppColors.infoSubtle, AppColors.info, AppColors.info),
      AppStatusType.offline => (AppColors.grey200, AppColors.grey700, AppColors.grey500),
      AppStatusType.draft => (AppColors.grey200, AppColors.grey700, AppColors.grey500),
      AppStatusType.error => (AppColors.errorSubtle, AppColors.error, AppColors.error),
      AppStatusType.accessible => (AppColors.successSubtle, AppColors.nodeAccessible, AppColors.nodeAccessible),
      AppStatusType.warning => (AppColors.warningSubtle, AppColors.warning, AppColors.warning),
      AppStatusType.info => (AppColors.primarySubtle, AppColors.primary, AppColors.primary),
    };

    final padding = isCompact
        ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 4);

    final fontStyle = isCompact ? AppTypography.labelSmall : AppTypography.labelMedium;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: isCompact ? 6 : 8,
              height: isCompact ? 6 : 8,
              decoration: BoxDecoration(
                color: dot,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: isCompact ? 4 : 6),
          ],
          Text(
            label,
            style: fontStyle.copyWith(
              color: fg,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
