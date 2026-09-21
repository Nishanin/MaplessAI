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

  final List<Widget> _destinations = const [
    HomeScreen(),
    MapViewScreen(),
    CreatorMappingScreen(),
    NavigationScreen(),
    AiChatScreen(),
  ];

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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: const Icon(Icons.hub_outlined, color: Colors.white, size: 20),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Text(
              'MapLess AI',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Buildings',
            icon: const Icon(Icons.apartment_outlined, size: 20, color: AppColors.textSecondary),
            onPressed: () => Navigator.of(context).pushNamed(AppRouter.buildings),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined, size: 20, color: AppColors.textSecondary),
            onPressed: () => Navigator.of(context).pushNamed(AppRouter.settings),
          ),
          IconButton(
            tooltip: 'Profile',
            icon: const Icon(Icons.person_outline, size: 20, color: AppColors.textSecondary),
            onPressed: () => Navigator.of(context).pushNamed(AppRouter.profile),
          ),
          if (authState.user != null) ...[
            GestureDetector(
              onTap: () => Navigator.of(context).pushNamed(AppRouter.profile),
              child: Center(
                child: AppStatusChip(
                  label: authState.user!.role == UserRole.creator ? 'CREATOR' : 'VISITOR',
                  status: authState.user!.role == UserRole.creator
                      ? AppStatusType.active
                      : AppStatusType.info,
                  isCompact: true,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout_outlined, size: 20, color: AppColors.textSecondary),
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
        children: _destinations,
      ),
      bottomNavigationBar: AppNavigationBar(
        currentIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
