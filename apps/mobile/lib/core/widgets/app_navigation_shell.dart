import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Navigation Shell Bar for the MapLess AI Application
/// Provides consistent Material 3 NavigationBar across primary destinations.
class AppNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool isCreator;

  const AppNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    this.isCreator = true,
  });

  @override
  Widget build(BuildContext context) {
    final destinations = isCreator
        ? const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: AppColors.primary),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map, color: AppColors.primary),
              label: 'Map',
            ),
            NavigationDestination(
              icon: Icon(Icons.add_location_alt_outlined),
              selectedIcon: Icon(Icons.add_location_alt, color: AppColors.primary),
              label: 'Creator',
            ),
            NavigationDestination(
              icon: Icon(Icons.alt_route_outlined),
              selectedIcon: Icon(Icons.alt_route, color: AppColors.primary),
              label: 'Routes',
            ),
            NavigationDestination(
              icon: Icon(Icons.smart_toy_outlined),
              selectedIcon: Icon(Icons.smart_toy, color: AppColors.primary),
              label: 'AI Chat',
            ),
          ]
        : const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: AppColors.primary),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map, color: AppColors.primary),
              label: 'Map',
            ),
            NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore, color: AppColors.primary),
              label: 'Explore',
            ),
            NavigationDestination(
              icon: Icon(Icons.alt_route_outlined),
              selectedIcon: Icon(Icons.alt_route, color: AppColors.primary),
              label: 'Routes',
            ),
            NavigationDestination(
              icon: Icon(Icons.smart_toy_outlined),
              selectedIcon: Icon(Icons.smart_toy, color: AppColors.primary),
              label: 'AI Chat',
            ),
          ];

    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onDestinationSelected,
      backgroundColor: AppColors.surface,
      elevation: 3,
      indicatorColor: AppColors.primarySubtle,
      destinations: destinations,
    );
  }
}
