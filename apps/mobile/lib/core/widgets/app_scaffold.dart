import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../theme/app_typography.dart';

/// Common application scaffold with responsive layout and standard header
/// Owner: Nishant (Presentation Shell)
class AppScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? titleWidget;
  final Widget body;
  final List<Widget>? actions;
  final Widget? leading;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Widget? drawer;
  final Color? backgroundColor;
  final bool showAppBar;
  final bool automaticallyImplyLeading;

  const AppScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.titleWidget,
    required this.body,
    this.actions,
    this.leading,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.drawer,
    this.backgroundColor,
    this.showAppBar = true,
    this.automaticallyImplyLeading = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? AppColors.background,
      appBar: showAppBar
          ? AppBar(
              automaticallyImplyLeading: automaticallyImplyLeading,
              leading: leading,
              title: titleWidget ??
                  Column(
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
              bottom: const PreferredSize(
                preferredSize: Size.fromHeight(1.0),
                child: Divider(height: 1, color: AppColors.border),
              ),
            )
          : null,
      drawer: drawer,
      body: SafeArea(child: body),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
