import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/state/auth_state.dart';
import '../../../../core/state/spatial_state.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_status_chip.dart';
import '../../state/mapping_controller.dart';
import '../widgets/create_building_dialog.dart';

/// Main Dashboard Screen with Role-Specific Views
/// Supports distinct Creator Studio, Visitor Navigation, and Starter Overview.
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
    // Pre-load common baseline dataset
    Future.microtask(() => ref.read(mappingProvider.notifier).loadMockDataset());
  }

  Future<void> _handleCreateBuilding() async {
    final newBuilding = await CreateBuildingDialog.show(context);
    if (newBuilding != null && mounted) {
      ref.read(spatialStateProvider.notifier).selectBuilding(newBuilding);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created building "${newBuilding.name}"')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final mappingState = ref.watch(mappingProvider);
    final spatialState = ref.watch(spatialStateProvider);

    final userRole = authState.user?.role;
    final isVisitor = userRole == UserRole.visitor;
    final isCreator = userRole == UserRole.creator;

    final activeBuildingName = spatialState.selectedBuilding?.name ??
        mappingState.building?.name ??
        'Academic Block 1 (AB-1)';
    final activeFloorName = spatialState.selectedFloor?.name ??
        mappingState.currentFloor?.name ??
        'Ground Floor (Floor 1)';

    return AppScaffold(
      title: isCreator
          ? 'Creator Studio'
          : isVisitor
              ? 'Indoor Navigation'
              : AppStrings.appName,
      body: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Banner Card
            AppCard(
              backgroundColor: isCreator
                  ? AppColors.primaryDark
                  : isVisitor
                      ? AppColors.primary
                      : AppColors.primary,
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
                          isCreator
                              ? 'MAPLESS Creator Studio'
                              : isVisitor
                                  ? 'MAPLESS Indoor Navigation'
                                  : AppStrings.appName,
                          style: AppTypography.headlineMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      AppStatusChip(
                        label: isCreator
                            ? 'CREATOR STUDIO'
                            : isVisitor
                                ? 'VISITOR MODE'
                                : 'V1 LIVE',
                        status: isCreator || !isVisitor
                            ? AppStatusType.active
                            : AppStatusType.info,
                        isCompact: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    isCreator
                        ? 'Create and maintain indoor maps'
                        : isVisitor
                            ? 'Explore and navigate mapped buildings'
                            : AppStrings.appTagline,
                    style: AppTypography.bodyMedium.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isCreator
                              ? Icons.build_circle_outlined
                              : isVisitor
                                  ? Icons.explore_outlined
                                  : Icons.info_outline,
                          color: Colors.amberAccent,
                          size: 18,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            isCreator
                                ? 'Author floor plans, capture sensor dead reckoning, and publish versions.'
                                : isVisitor
                                    ? 'Select destinations, follow turn-by-turn routes, and locate facilities.'
                                    : AppStrings.v1Notice,
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Context Status Card
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
                  isCreator
                      ? 'Floor: $activeFloorName • '
                          '${mappingState.nodes.isNotEmpty ? mappingState.nodes.length : 7} Nodes • '
                          '${mappingState.edges.isNotEmpty ? mappingState.edges.length : 6} Edges'
                      : 'Floor: $activeFloorName • '
                          '${spatialState.availableFloors.isNotEmpty ? spatialState.availableFloors.length : 3} Floors Available',
                  style: AppTypography.bodySmall,
                ),
                trailing: TextButton(
                  onPressed: () => Navigator.pushNamed(context, AppRouter.buildings),
                  child: Text(isCreator ? 'Change Project' : 'Change'),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Quick Actions Bar
            if (isCreator) ...[
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Create Building',
                      icon: Icons.add_business,
                      onPressed: _handleCreateBuilding,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppButton(
                      label: 'Continue Mapping',
                      icon: Icons.directions_walk,
                      variant: AppButtonVariant.outlined,
                      onPressed: () => Navigator.pushNamed(context, AppRouter.creator),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
            ] else if (isVisitor) ...[
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Browse Buildings',
                      icon: Icons.apartment,
                      onPressed: () => Navigator.pushNamed(context, AppRouter.buildings),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppButton(
                      label: 'My Location',
                      icon: Icons.my_location,
                      variant: AppButtonVariant.outlined,
                      onPressed: () => Navigator.pushNamed(context, AppRouter.visitor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

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
                  isCreator
                      ? 'Creator Workspace'
                      : isVisitor
                          ? 'Navigation Services'
                          : 'All Destinations',
                  style: AppTypography.labelSmall.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Feature Cards Grid — STRICTLY ROLE-SEGREGATED
            if (isCreator)
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.md,
                childAspectRatio: 1.1,
                children: [
                  _FeatureCard(
                    title: 'Creator Mapping',
                    subtitle: 'Sensors & Walkthrough',
                    icon: Icons.directions_walk,
                    color: Colors.green,
                    onTap: () => Navigator.pushNamed(context, AppRouter.creator),
                  ),
                  _FeatureCard(
                    title: 'Map Editor',
                    subtitle: 'Nodes & Edges Canvas',
                    icon: Icons.edit_road,
                    color: Colors.teal,
                    onTap: () => Navigator.pushNamed(context, AppRouter.creatorEditor),
                  ),
                  _FeatureCard(
                    title: 'Graph Validation',
                    subtitle: 'Integrity & Previews',
                    icon: Icons.fact_check_outlined,
                    color: Colors.indigo,
                    onTap: () => Navigator.pushNamed(context, AppRouter.creatorPreview),
                  ),
                  _FeatureCard(
                    title: 'Publish Map',
                    subtitle: 'Snapshot & Version',
                    icon: Icons.publish_outlined,
                    color: Colors.deepPurple,
                    onTap: () => Navigator.pushNamed(context, AppRouter.creatorPublish),
                  ),
                  _FeatureCard(
                    title: 'Version History',
                    subtitle: 'Snapshots & Rollback',
                    icon: Icons.history,
                    color: Colors.blueGrey,
                    onTap: () => Navigator.pushNamed(context, AppRouter.versionHistory),
                  ),
                  _FeatureCard(
                    title: 'Indoor Map View',
                    subtitle: '2D Graph Inspection',
                    icon: Icons.map,
                    color: AppColors.primary,
                    onTap: () => Navigator.pushNamed(context, AppRouter.map),
                  ),
                ],
              )
            else if (isVisitor)
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
                    title: 'Indoor Map View',
                    subtitle: '2D Graph Canvas',
                    icon: Icons.map,
                    color: AppColors.primary,
                    onTap: () => Navigator.pushNamed(context, AppRouter.map),
                  ),
                  _FeatureCard(
                    title: 'Wayfinding & POIs',
                    subtitle: 'Rooms, Elevators, Exits',
                    icon: Icons.explore,
                    color: Colors.teal,
                    onTap: () => Navigator.pushNamed(context, AppRouter.visitor),
                  ),
                  _FeatureCard(
                    title: 'Spatial Route',
                    subtitle: 'Turn-by-Turn Paths',
                    icon: Icons.alt_route,
                    color: Colors.deepPurple,
                    onTap: () => Navigator.pushNamed(context, AppRouter.navigation),
                  ),
                  _FeatureCard(
                    title: 'AI Assistant',
                    subtitle: 'SLM Campus Query',
                    icon: Icons.smart_toy,
                    color: Colors.indigo,
                    onTap: () => Navigator.pushNamed(context, AppRouter.aiAssistant),
                  ),
                  _FeatureCard(
                    title: 'Building Overview',
                    subtitle: 'Multi-Floor Stack',
                    icon: Icons.layers_outlined,
                    color: Colors.orange,
                    onTap: () => Navigator.pushNamed(context, AppRouter.buildingOverview),
                  ),
                ],
              )
            else
              // Starter / Unauthenticated Overview
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
