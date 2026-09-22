import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/state/auth_state.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/app_navigation_shell.dart';
import '../../../../core/widgets/app_status_chip.dart';
import 'ai_chat_screen.dart';
import 'creator_mapping_screen.dart';
import 'home_screen.dart';
import 'map_view_screen.dart';
import 'navigation_screen.dart';
import 'visitor_screen.dart';

/// Primary Application Shell with Bottom Navigation
/// Owner: Nishant (Presentation Shell)
class HomeShellScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const HomeShellScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends ConsumerState<HomeShellScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
  }

  Future<void> _handleLogout() async {
    final confirmed = await AppDialogs.showConfirm(
      context,
      title: 'Sign Out',
      message: 'Are you sure you want to sign out of MapLess AI?',
      confirmLabel: 'Sign Out',
      isDestructive: true,
      icon: Icons.logout,
    );

    if (confirmed == true && mounted) {
      ref.read(authProvider.notifier).logout();
      Navigator.of(context).pushNamedAndRemoveUntil(AppRouter.login, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 380;
    final isCreator = authState.user?.role == UserRole.creator;

    final destinations = isCreator
        ? const [
            HomeScreen(),
            MapViewScreen(),
            CreatorMappingScreen(),
            NavigationScreen(),
            AiChatScreen(),
          ]
        : const [
            HomeScreen(),
            MapViewScreen(),
            VisitorScreen(),
            NavigationScreen(),
            AiChatScreen(),
          ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: AppSpacing.sm,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: const Icon(Icons.hub_outlined, color: Colors.white, size: 18),
            ),
            const SizedBox(width: AppSpacing.xs + 2),
            const Flexible(
              child: Text(
                'MapLess AI',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: AppColors.primary,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Buildings',
            icon: const Icon(Icons.apartment_outlined, size: 20, color: AppColors.textSecondary),
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            splashRadius: 18,
            onPressed: () => Navigator.of(context).pushNamed(AppRouter.buildings),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined, size: 20, color: AppColors.textSecondary),
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            splashRadius: 18,
            onPressed: () => Navigator.of(context).pushNamed(AppRouter.settings),
          ),
          if (!isCompact || authState.user == null)
            IconButton(
              tooltip: 'Profile',
              icon: const Icon(Icons.person_outline, size: 20, color: AppColors.textSecondary),
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              splashRadius: 18,
              onPressed: () => Navigator.of(context).pushNamed(AppRouter.profile),
            ),
          if (authState.user != null) ...[
            GestureDetector(
              onTap: () => Navigator.of(context).pushNamed(AppRouter.profile),
              child: Center(
                child: AppStatusChip(
                  label: isCreator ? 'CREATOR' : 'VISITOR',
                  status: isCreator ? AppStatusType.active : AppStatusType.info,
                  isCompact: true,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout_outlined, size: 20, color: AppColors.textSecondary),
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            splashRadius: 18,
            onPressed: _handleLogout,
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: destinations,
      ),
      bottomNavigationBar: AppNavigationBar(
        currentIndex: _currentIndex,
        isCreator: isCreator,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
