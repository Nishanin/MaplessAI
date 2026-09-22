import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/state/spatial_state.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_status_chip.dart';
import '../../state/mapping_controller.dart';

/// Main Dashboard Screen
/// Owner: Nishant (Presentation Shell)
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Pre-load common mock dataset
    Future.microtask(() => ref.read(mappingProvider.notifier).loadMockDataset());
  }

  @override
  Widget build(BuildContext context) {
    final mappingState = ref.watch(mappingProvider);
    final spatialState = ref.watch(spatialStateProvider);

    final activeBuildingName = spatialState.selectedBuilding?.name ??
        mappingState.building?.name ??
        'VIT Chennai Campus - AB1';
    final activeFloorName = spatialState.selectedFloor?.name ??
        mappingState.currentFloor?.name ??
        'Ground Floor';

    return AppScaffold(
      title: AppStrings.appName,
      body: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Banner Card
            AppCard(
              backgroundColor: AppColors.primary,
              borderRadius: AppSpacing.radiusLg,
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          AppStrings.appName,
                          style: AppTypography.headlineMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const AppStatusChip(
                        label: 'V1 LIVE',
                        status: AppStatusType.active,
                        isCompact: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    AppStrings.appTagline,
                    style: AppTypography.bodyMedium.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amberAccent, size: 18),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            AppStrings.v1Notice,
                            style: TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Dataset Status Card
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.secondarySubtle,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: const Icon(Icons.apartment, color: AppColors.secondary, size: 24),
                ),
                title: Text(
                  activeBuildingName,
                  style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Floor: $activeFloorName • '
                  '${mappingState.nodes.isNotEmpty ? mappingState.nodes.length : 6} Nodes • '
                  '${mappingState.edges.isNotEmpty ? mappingState.edges.length : 6} Edges',
                  style: AppTypography.bodySmall,
                ),
                trailing: TextButton(
                  onPressed: () => Navigator.pushNamed(context, AppRouter.buildings),
                  child: const Text('Change'),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Feature Modules Heading
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Feature Modules',
                    style: AppTypography.titleLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'All Destinations',
                  style: AppTypography.labelSmall.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Feature Cards Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              childAspectRatio: 1.1,
              children: [
                _FeatureCard(
                  title: 'Campus Buildings',
                  subtitle: 'Directory & Selection',
                  icon: Icons.apartment,
                  color: Colors.blue,
                  onTap: () => Navigator.pushNamed(context, AppRouter.buildings),
                ),
                _FeatureCard(
                  title: 'Visitor Mode',
                  subtitle: 'Wayfinding & Guidance',
                  icon: Icons.explore,
                  color: Colors.teal,
                  onTap: () => Navigator.pushNamed(context, AppRouter.visitor),
                ),
                _FeatureCard(
                  title: 'Indoor Map View',
                  subtitle: '2D Graph Canvas',
                  icon: Icons.map,
                  color: AppColors.primary,
                  onTap: () => Navigator.pushNamed(context, AppRouter.map),
                ),
                _FeatureCard(
                  title: 'Creator Mapping',
                  subtitle: 'Sensors & Walkthrough',
                  icon: Icons.directions_walk,
                  color: Colors.green,
                  onTap: () => Navigator.pushNamed(context, AppRouter.creator),
                ),
                _FeatureCard(
                  title: 'Spatial Route',
                  subtitle: 'A* / Dijkstra Path',
                  icon: Icons.alt_route,
                  color: Colors.deepPurple,
                  onTap: () => Navigator.pushNamed(context, AppRouter.navigation),
                ),
                _FeatureCard(
                  title: 'AI Assistant',
                  subtitle: 'SLM Natural Language',
                  icon: Icons.smart_toy,
                  color: Colors.indigo,
                  onTap: () => Navigator.pushNamed(context, AppRouter.aiAssistant),
                ),
                _FeatureCard(
                  title: 'Version History',
                  subtitle: 'Snapshots & Audit',
                  icon: Icons.history,
                  color: Colors.blueGrey,
                  onTap: () => Navigator.pushNamed(context, AppRouter.versionHistory),
                ),
                _FeatureCard(
                  title: 'User Profile',
                  subtitle: 'Account & Session',
                  icon: Icons.person_outline,
                  color: Colors.deepOrange,
                  onTap: () => Navigator.pushNamed(context, AppRouter.profile),
                ),
                _FeatureCard(
                  title: 'Settings',
                  subtitle: 'Preferences & Cache',
                  icon: Icons.settings_outlined,
                  color: Colors.brown,
                  onTap: () => Navigator.pushNamed(context, AppRouter.settings),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 4, vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            title,
            style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
