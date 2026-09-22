import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';

/// Reusable Standard Dialog System for MapLess AI
abstract final class AppDialogs {
  /// Shows a confirmation dialog with Confirm and Cancel actions
  static Future<bool?> showConfirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
    IconData icon = Icons.help_outline,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        icon: Icon(
          icon,
          size: 36,
          color: isDestructive ? AppColors.error : AppColors.primary,
        ),
        title: Text(
          title,
          style: AppTypography.headlineSmall,
          textAlign: TextAlign.center,
        ),
        content: Text(
          message,
          style: AppTypography.bodyMedium,
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          AppButton(
            label: confirmLabel,
            variant: isDestructive ? AppButtonVariant.danger : AppButtonVariant.primary,
            size: AppButtonSize.small,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
  }

  /// Shows an alert dialog with an OK button
  static Future<void> showAlert(
    BuildContext context, {
    required String title,
    required String message,
    String buttonLabel = 'OK',
    IconData icon = Icons.info_outline,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        icon: Icon(icon, size: 36, color: AppColors.primary),
        title: Text(
          title,
          style: AppTypography.headlineSmall,
          textAlign: TextAlign.center,
        ),
        content: Text(
          message,
          style: AppTypography.bodyMedium,
          textAlign: TextAlign.center,
        ),
        actions: [
          Center(
            child: AppButton(
              label: buttonLabel,
              size: AppButtonSize.small,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ),
        ],
      ),
    );
  }

  /// Shows an error dialog
  static Future<void> showError(
    BuildContext context, {
    required String title,
    required String message,
    String buttonLabel = 'Dismiss',
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        icon: const Icon(Icons.error_outline, size: 36, color: AppColors.error),
        title: Text(
          title,
          style: AppTypography.headlineSmall.copyWith(color: AppColors.error),
          textAlign: TextAlign.center,
        ),
        content: Text(
          message,
          style: AppTypography.bodyMedium,
          textAlign: TextAlign.center,
        ),
        actions: [
          Center(
            child: AppButton(
              label: buttonLabel,
              variant: AppButtonVariant.danger,
              size: AppButtonSize.small,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ),
        ],
      ),
    );
  }
}
