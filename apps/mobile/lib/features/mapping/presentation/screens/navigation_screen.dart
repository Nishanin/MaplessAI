import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../navigation/domain/spatial_graph.dart';
import '../../../navigation/state/navigation_controller.dart';
import '../../state/mapping_controller.dart';
import '../widgets/indoor_canvas.dart';

/// Navigation & Route Screen
/// Owner: Nishant (Presentation layer consuming Pratik's navigationProvider)
class NavigationScreen extends ConsumerStatefulWidget {
  const NavigationScreen({super.key});

  @override
  ConsumerState<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends ConsumerState<NavigationScreen> {
  String? _startNodeId;
  String? _destNodeId;

  @override
  void initState() {
    super.initState();
    final mappingState = ref.read(mappingProvider);
    _startNodeId = mappingState.visitorCurrentNodeId ?? (mappingState.nodes.isNotEmpty ? mappingState.nodes.first.id : null);
    _destNodeId = mappingState.nodes.length > 3 ? mappingState.nodes[3].id : null;
  }

  SpatialGraph _buildSpatialGraph() {
    final mappingState = ref.read(mappingProvider);
    final graph = SpatialGraph();
    for (final node in mappingState.nodes) {
      graph.addNode(node);
    }
    for (final edge in mappingState.edges) {
      graph.addEdge(edge);
    }
    return graph;
  }

  @override
  Widget build(BuildContext context) {
    final mappingState = ref.watch(mappingProvider);
    final navState = ref.watch(navigationProvider);
    final navNotifier = ref.read(navigationProvider.notifier);

    return AppScaffold(
      title: 'Indoor Route Guidance',
      body: Column(
        children: [
          // Route Input Card
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.my_location, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _startNodeId,
                          hint: const Text('Start Location'),
                          items: mappingState.nodes.map((n) {
                            return DropdownMenuItem(value: n.id, child: Text(n.name));
                          }).toList(),
                          onChanged: (val) {
                            setState(() => _startNodeId = val);
                            if (val != null) navNotifier.setStartNode(val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _destNodeId,
                          hint: const Text('Destination Location'),
                          items: mappingState.nodes.map((n) {
                            return DropdownMenuItem(value: n.id, child: Text(n.name));
                          }).toList(),
                          onChanged: (val) {
                            setState(() => _destNodeId = val);
                            if (val != null) navNotifier.setDestinationNode(val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: navState.isLoading
                          ? null
                          : () {
                              if (_startNodeId != null && _destNodeId != null) {
                                navNotifier.setStartNode(_startNodeId!);
                                navNotifier.setDestinationNode(_destNodeId!);
                                final graph = _buildSpatialGraph();
                                navNotifier.calculateRoute(
                                  graph,
                                  mappingState.building?.id ?? 'vit-ce',
                                );
                              }
                            },
                      icon: const Icon(Icons.directions),
                      label: Text(navState.isLoading ? 'Computing...' : 'Find Route'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Mini Map Preview with active route highlight
          Expanded(
            flex: 3,
            child: IndoorCanvas(
              nodes: mappingState.nodes,
              edges: mappingState.edges,
              selectedNodeId: _destNodeId,
              visitorNodeId: _startNodeId,
              highlightedPathNodeIds: navState.currentRoute?.pathNodeIds ?? [],
            ),
          ),

          // Turn by Turn Sheet
          if (navState.currentRoute != null)
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Distance: ${navState.currentRoute!.totalDistance}m • '
                      'Est: ${navState.currentRoute!.estimatedTimeSeconds}s',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: navState.currentRoute!.turnInstructions.length,
                        itemBuilder: (context, index) {
                          final step = navState.currentRoute!.turnInstructions[index];
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 12,
                              backgroundColor: AppColors.primary,
                              child: Text(
                                '${step.step}',
                                style: const TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            ),
                            title: Text(step.instruction),
                            subtitle: Text('${step.distance}m • Bearing: ${step.bearing}°'),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
