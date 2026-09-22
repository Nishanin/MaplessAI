import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../theme/app_typography.dart';

enum AppCardVariant { elevated, outlined, flat }

/// Production Card component for MapLess AI
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final AppCardVariant variant;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;

  const AppCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.cardPadding,
    this.variant = AppCardVariant.elevated,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = AppSpacing.radiusMd,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBg = backgroundColor ?? (variant == AppCardVariant.flat ? AppColors.grey100 : Colors.white);
    final borderSide = variant == AppCardVariant.outlined
        ? BorderSide(color: borderColor ?? AppColors.border, width: 1)
        : (borderColor != null ? BorderSide(color: borderColor!, width: 1) : BorderSide.none);

    final elevation = switch (variant) {
      AppCardVariant.elevated => AppSpacing.elevationLow,
      AppCardVariant.outlined => AppSpacing.elevationNone,
      AppCardVariant.flat => AppSpacing.elevationNone,
    };

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      side: borderSide,
    );

    return Material(
      color: effectiveBg,
      elevation: elevation,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// Action Card with leading icon, title, subtitle, and trailing chevron
class AppActionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color? iconColor;
  final Color? iconBgColor;
  final VoidCallback onTap;
  final Widget? trailing;
  final Widget? badge;

  const AppActionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.iconColor,
    this.iconBgColor,
    required this.onTap,
    this.trailing,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? AppColors.primary;
    final effectiveIconBg = iconBgColor ?? AppColors.primarySubtle;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: effectiveIconBg,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(icon, color: effectiveIconColor, size: AppSpacing.iconMd),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: AppTypography.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      badge!,
                    ],
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AppTypography.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          trailing ?? const Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
