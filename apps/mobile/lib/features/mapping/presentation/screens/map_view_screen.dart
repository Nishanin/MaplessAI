import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/state/spatial_state.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../state/mapping_controller.dart';
import '../widgets/indoor_canvas.dart';

/// Interactive Map View Screen
/// Owner: Nishant (Complete UI/UX)
class MapViewScreen extends ConsumerWidget {
  const MapViewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mappingProvider);
    final spatialState = ref.watch(spatialStateProvider);

    final activeLocationId = spatialState.selectedCurrentLocation?.id ?? state.visitorCurrentNodeId;

    return AppScaffold(
      title: 'Indoor Map Canvas',
      body: Column(
        children: [
          // Instructions & Context Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                const Icon(Icons.touch_app, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Building: ${spatialState.selectedBuilding?.name ?? "AB-1"} • '
                    'Floor: ${spatialState.selectedFloor?.name ?? "Floor 1"}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),

          // Interactive 2D Canvas
          Expanded(
            child: IndoorCanvas(
              nodes: state.nodes.isNotEmpty ? state.nodes : spatialState.availableNodes,
              edges: state.edges,
              selectedNodeId: state.selectedNodeId,
              visitorNodeId: activeLocationId,
              onNodeTapped: (node) {
                ref.read(mappingProvider.notifier).selectNode(node.id);
                ref.read(spatialStateProvider.notifier).setCurrentLocation(node);
              },
            ),
          ),

          // Node Selection Bar
          if (state.nodes.isNotEmpty || spatialState.availableNodes.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  const Text('My Location: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: activeLocationId ??
                          (state.nodes.isNotEmpty
                              ? state.nodes.first.id
                              : spatialState.availableNodes.first.id),
                      items: (state.nodes.isNotEmpty ? state.nodes : spatialState.availableNodes)
                          .map((n) {
                        return DropdownMenuItem(
                          value: n.id,
                          child: Text('${n.name} (${n.category})'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          ref.read(mappingProvider.notifier).setVisitorLocation(val);
                          ref.read(spatialStateProvider.notifier).setCurrentLocationById(val);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
