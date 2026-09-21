import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../theme/app_typography.dart';

/// Standard Top App Bar for MapLess AI
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBottomBorder;
  final Widget? bottom;
  final double bottomHeight;

  const AppTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.showBottomBorder = true,
    this.bottom,
    this.bottomHeight = 0,
  });

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + bottomHeight + (showBottomBorder ? 1.0 : 0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: leading,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: AppTypography.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          if (subtitle != null) ...[
            Text(
              subtitle!,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
      actions: actions != null
          ? [
              ...actions!,
              const SizedBox(width: AppSpacing.sm),
            ]
          : null,
      bottom: showBottomBorder
          ? PreferredSize(
              preferredSize: Size.fromHeight(bottomHeight + 1.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ?bottom,
                  const Divider(height: 1, color: AppColors.border),
                ],
              ),
            )
          : (bottom != null ? PreferredSize(preferredSize: Size.fromHeight(bottomHeight), child: bottom!) : null),
    );
  }
}
