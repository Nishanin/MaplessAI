import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
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

    return AppScaffold(
      title: 'Indoor Map Canvas',
      body: Column(
        children: [
          // Instructions Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.blue.shade50,
            child: const Row(
              children: [
                Icon(Icons.touch_app, size: 20, color: AppColors.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Select a node to set your current location (V1 Manual Visitor Location).',
                    style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),

          // Interactive 2D Canvas
          Expanded(
            child: IndoorCanvas(
              nodes: state.nodes,
              edges: state.edges,
              selectedNodeId: state.selectedNodeId,
              visitorNodeId: state.visitorCurrentNodeId,
              onNodeTapped: (node) {
                ref.read(mappingProvider.notifier).selectNode(node.id);
              },
            ),
          ),

          // Node Selection Bar
          if (state.nodes.isNotEmpty)
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
                      value: state.visitorCurrentNodeId ?? state.nodes.first.id,
                      items: state.nodes.map((n) {
                        return DropdownMenuItem(
                          value: n.id,
                          child: Text('${n.name} (${n.category})'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          ref.read(mappingProvider.notifier).setVisitorLocation(val);
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
