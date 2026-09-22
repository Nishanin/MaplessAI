import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';

/// Reusable Error State component for MapLess AI
class AppErrorState extends StatefulWidget {
  final String title;
  final String message;
  final String? technicalDetails;
  final VoidCallback? onRetry;
  final String retryLabel;
  final VoidCallback? onSecondaryAction;
  final String? secondaryActionLabel;
  final IconData icon;

  const AppErrorState({
    super.key,
    this.title = 'Something went wrong',
    required this.message,
    this.technicalDetails,
    this.onRetry,
    this.retryLabel = 'Try Again',
    this.onSecondaryAction,
    this.secondaryActionLabel,
    this.icon = Icons.error_outline,
  });

  @override
  State<AppErrorState> createState() => _AppErrorStateState();
}

class _AppErrorStateState extends State<AppErrorState> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: const BoxDecoration(
                color: AppColors.errorSubtle,
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.icon,
                size: 48,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              widget.title,
              style: AppTypography.headlineSmall.copyWith(color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.message,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (widget.technicalDetails != null) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () {
                  setState(() {
                    _showDetails = !_showDetails;
                  });
                },
                child: Text(
                  _showDetails ? 'Hide Details' : 'Show Error Details',
                  style: AppTypography.labelSmall.copyWith(color: AppColors.primary),
                ),
              ),
              if (_showDetails) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.grey100,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    widget.technicalDetails!,
                    style: AppTypography.monoCoordinates.copyWith(
                      color: AppColors.error,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.onSecondaryAction != null && widget.secondaryActionLabel != null) ...[
                  AppButton(
                    label: widget.secondaryActionLabel!,
                    variant: AppButtonVariant.outlined,
                    size: AppButtonSize.small,
                    onPressed: widget.onSecondaryAction,
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                if (widget.onRetry != null)
                  AppButton(
                    label: widget.retryLabel,
                    icon: Icons.refresh,
                    size: AppButtonSize.small,
                    onPressed: widget.onRetry,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
