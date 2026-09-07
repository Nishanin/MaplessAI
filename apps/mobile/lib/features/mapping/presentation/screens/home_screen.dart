import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../state/mapping_controller.dart';
import 'ai_chat_screen.dart';
import 'creator_mapping_screen.dart';
import 'map_view_screen.dart';
import 'navigation_screen.dart';
import 'version_history_screen.dart';

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

    return AppScaffold(
      title: AppStrings.appName,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Banner
            Card(
              color: AppColors.primary,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      AppStrings.appName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      AppStrings.appTagline,
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.amberAccent, size: 18),
                          SizedBox(width: 8),
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
            ),
            const SizedBox(height: 16),

            // Dataset Status
            Card(
              child: ListTile(
                leading: const Icon(Icons.dataset, color: AppColors.secondary),
                title: Text(
                  mappingState.building?.name ?? 'Loading VIT Dataset...',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Floor: ${mappingState.currentFloor?.name ?? "..."} • '
                  '${mappingState.nodes.length} Nodes • '
                  '${mappingState.edges.length} Edges',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.read(mappingProvider.notifier).loadMockDataset(),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Quick Action Grid
            const Text(
              'Feature Modules',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                _FeatureCard(
                  title: 'Indoor Map View',
                  subtitle: '2D Graph Canvas',
                  icon: Icons.map,
                  color: AppColors.primary,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MapViewScreen()),
                  ),
                ),
                _FeatureCard(
                  title: 'Creator Mapping',
                  subtitle: 'Sensors & Walkthrough',
                  icon: Icons.directions_walk,
                  color: Colors.teal,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreatorMappingScreen()),
                  ),
                ),
                _FeatureCard(
                  title: 'Spatial Route',
                  subtitle: 'A* / Dijkstra Path',
                  icon: Icons.alt_route,
                  color: Colors.deepPurple,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NavigationScreen()),
                  ),
                ),
                _FeatureCard(
                  title: 'AI Assistant',
                  subtitle: 'SLM Natural Language',
                  icon: Icons.smart_toy,
                  color: Colors.indigo,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AiChatScreen()),
                  ),
                ),
                _FeatureCard(
                  title: 'Version History',
                  subtitle: 'Snapshots & Audit',
                  icon: Icons.history,
                  color: Colors.blueGrey,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const VersionHistoryScreen()),
                  ),
                ),
              ],
            ),
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
