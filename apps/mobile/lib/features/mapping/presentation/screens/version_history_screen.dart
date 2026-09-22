import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/state/auth_state.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../versioning/state/versioning_controller.dart';
import '../../state/mapping_controller.dart';

/// Version History Screen
/// Owner: Nishant (Presentation layer consuming Piyush's versioningProvider)
class VersionHistoryScreen extends ConsumerStatefulWidget {
  const VersionHistoryScreen({super.key});

  @override
  ConsumerState<VersionHistoryScreen> createState() => _VersionHistoryScreenState();
}

class _VersionHistoryScreenState extends ConsumerState<VersionHistoryScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final buildingId = ref.read(mappingProvider).building?.id ?? 'vit-ce';
      ref.read(versioningProvider.notifier).fetchHistory(buildingId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final versionState = ref.watch(versioningProvider);
    final mappingState = ref.watch(mappingProvider);

    return AppScaffold(
      title: 'Map Version History',
      body: Column(
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.blueGrey.shade50,
            child: const Row(
              children: [
                Icon(Icons.inventory_2_outlined, size: 20, color: Colors.blueGrey),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Immutable point-in-time graph snapshots. Supports audit & rollback.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          // Snapshots List
          Expanded(
            child: versionState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: versionState.history.length,
                    itemBuilder: (context, index) {
                      final item = versionState.history[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary,
                            child: Text(
                              'v${item.versionNumber}',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                          title: Text(
                            item.versionTag,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${item.changeSummary}\nBy: ${item.createdBy}',
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            icon: const Icon(Icons.restore, color: Colors.orange),
                            tooltip: 'Rollback to this snapshot',
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Rollback to snapshot v${item.versionNumber} initiated'),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.camera_alt, color: Colors.white),
        label: const Text('Create Snapshot', style: TextStyle(color: Colors.white)),
        onPressed: () {
          final author = ref.read(authProvider).user?.name ?? 'Creator';
          ref.read(versioningProvider.notifier).createSnapshot(
                mappingState.building?.id ?? 'bld-vit-cc-01',
                {'nodes': mappingState.nodes.length, 'edges': mappingState.edges.length},
                'Manual snapshot from app',
                author,
              );
        },
      ),
    );
  }
}
