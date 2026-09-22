import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../theme/app_typography.dart';

enum AppButtonVariant { primary, secondary, outlined, text, danger }
enum AppButtonSize { small, medium, large }

/// Standardized Button Component for MapLess AI
/// Supports multiple variants, sizes, icon leading/trailing, loading spinner, and full-width mode.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final bool isIconTrailing;
  final bool isLoading;
  final bool isFullWidth;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.icon,
    this.isIconTrailing = false,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveEnabled = onPressed != null && !isLoading;

    final EdgeInsets padding = switch (size) {
      AppButtonSize.small => const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      AppButtonSize.medium => const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      AppButtonSize.large => const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    };

    final TextStyle textStyle = switch (size) {
      AppButtonSize.small => AppTypography.labelMedium,
      AppButtonSize.medium => AppTypography.labelLarge,
      AppButtonSize.large => AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
    };

    final double iconSize = switch (size) {
      AppButtonSize.small => 16.0,
      AppButtonSize.medium => 18.0,
      AppButtonSize.large => 22.0,
    };

    final Widget content = isLoading
        ? SizedBox(
            height: iconSize,
            width: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2.0,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getLoadingIndicatorColor(),
              ),
            ),
          )
        : Row(
            mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null && !isIconTrailing) ...[
                Icon(icon, size: iconSize),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(
                child: Text(
                  label,
                  style: textStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (icon != null && isIconTrailing) ...[
                const SizedBox(width: AppSpacing.sm),
                Icon(icon, size: iconSize),
              ],
            ],
          );

    Widget button;
    switch (variant) {
      case AppButtonVariant.primary:
        button = ElevatedButton(
          onPressed: effectiveEnabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.grey300,
            disabledForegroundColor: AppColors.grey600,
            padding: padding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
          ),
          child: content,
        );
      case AppButtonVariant.secondary:
        button = ElevatedButton(
          onPressed: effectiveEnabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.grey300,
            disabledForegroundColor: AppColors.grey600,
            padding: padding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
          ),
          child: content,
        );
      case AppButtonVariant.outlined:
        button = OutlinedButton(
          onPressed: effectiveEnabled ? onPressed : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            disabledForegroundColor: AppColors.grey400,
            side: BorderSide(
              color: effectiveEnabled ? AppColors.primary : AppColors.grey300,
              width: 1.2,
            ),
            padding: padding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
          ),
          child: content,
        );
      case AppButtonVariant.text:
        button = TextButton(
          onPressed: effectiveEnabled ? onPressed : null,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            disabledForegroundColor: AppColors.grey400,
            padding: padding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
          ),
          child: content,
        );
      case AppButtonVariant.danger:
        button = ElevatedButton(
          onPressed: effectiveEnabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.grey300,
            disabledForegroundColor: AppColors.grey600,
            padding: padding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
          ),
          child: content,
        );
    }

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }

  Color _getLoadingIndicatorColor() {
    switch (variant) {
      case AppButtonVariant.primary:
      case AppButtonVariant.secondary:
      case AppButtonVariant.danger:
        return Colors.white;
      case AppButtonVariant.outlined:
      case AppButtonVariant.text:
        return AppColors.primary;
    }
  }
}
