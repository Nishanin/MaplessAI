import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/models/node_model.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/state/spatial_state.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../state/mapping_controller.dart';
import '../widgets/indoor_canvas.dart';

/// Interactive 2D Indoor Map Screen with Multi-Floor Switcher & Node Inspector
/// Owner: Nishant (Phase 5 — Interactive 2D Indoor Map)
class MapViewScreen extends ConsumerStatefulWidget {
  const MapViewScreen({super.key});

  @override
  ConsumerState<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends ConsumerState<MapViewScreen> {
  final TransformationController _transformController = TransformationController();
  bool _showLabels = true;
  bool _showAccessibility = true;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _zoomIn() {
    final matrix = _transformController.value.clone();
    matrix.scaleByDouble(1.25, 1.25, 1.0, 1.0);
    _transformController.value = matrix;
  }

  void _zoomOut() {
    final matrix = _transformController.value.clone();
    matrix.scaleByDouble(0.8, 0.8, 1.0, 1.0);
    _transformController.value = matrix;
  }

  void _resetView() {
    _transformController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    final mappingState = ref.watch(mappingProvider);
    final spatialState = ref.watch(spatialStateProvider);
    final spatialNotifier = ref.read(spatialStateProvider.notifier);

    final activeBuilding = spatialState.selectedBuilding ?? mappingState.building;
    final activeFloor = spatialState.selectedFloor ?? mappingState.currentFloor;
    final floors = spatialState.availableFloors;
    final nodes = spatialState.availableNodes.isNotEmpty
        ? spatialState.availableNodes
        : mappingState.nodes;
    final edges = spatialState.availableEdges.isNotEmpty
        ? spatialState.availableEdges
        : mappingState.edges;

    final activeLocationId =
        spatialState.selectedCurrentLocation?.id ?? mappingState.visitorCurrentNodeId;
    final selectedNode = spatialState.selectedNode;

    return AppScaffold(
      title: 'Indoor Map Canvas',
      actions: [
        IconButton(
          tooltip: _showAccessibility ? 'Hide Accessibility Badges' : 'Show Accessibility Badges',
          icon: Icon(
            _showAccessibility ? Icons.accessible_forward : Icons.not_accessible,
            color: _showAccessibility ? AppColors.primary : Colors.grey,
          ),
          onPressed: () => setState(() => _showAccessibility = !_showAccessibility),
        ),
        IconButton(
          tooltip: 'Building Overview',
          icon: const Icon(Icons.apartment_outlined),
          onPressed: () {
            Navigator.pushNamed(context, AppRouter.buildingOverview);
          },
        ),
      ],
      body: Stack(
        children: [
          Column(
            children: [
              // Top Context Banner with active building & floor switcher link
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.blue.shade50,
                child: Row(
                  children: [
                    const Icon(Icons.touch_app, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${activeBuilding?.name ?? "Campus Building"} • ${activeFloor?.name ?? "Ground Floor"}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () {
                        Navigator.pushNamed(context, AppRouter.buildingOverview);
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text(
                          'Multi-Floor',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Interactive 2D Map Canvas
              Expanded(
                child: IndoorCanvas(
                  nodes: nodes,
                  edges: edges,
                  selectedNodeId: selectedNode?.id ?? spatialState.selectedDestination?.id,
                  visitorNodeId: activeLocationId,
                  transformationController: _transformController,
                  showLabels: _showLabels,
                  showAccessibilityBadges: _showAccessibility,
                  onNodeTapped: (node) {
                    spatialNotifier.selectNode(node);
                    ref.read(mappingProvider.notifier).selectNode(node.id);
                  },
                ),
              ),

              // Node Inspector Bottom Sheet Panel (appears when node is tapped)
              if (selectedNode != null)
                _NodeInspectorCard(
                  node: selectedNode,
                  isStartLocation: selectedNode.id == activeLocationId,
                  isDestination: selectedNode.id == spatialState.selectedDestination?.id,
                  onSetStart: () {
                    spatialNotifier.setCurrentLocation(selectedNode);
                    ref.read(mappingProvider.notifier).setVisitorLocation(selectedNode.id);
                  },
                  onSetDestination: () {
                    spatialNotifier.setDestination(selectedNode);
                  },
                  onDismiss: () {
                    spatialNotifier.selectNode(null);
                  },
                )
              else if (nodes.isNotEmpty)
                // Default Location Quick Selection Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.my_location, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Location: ',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      Expanded(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: nodes.any((n) => n.id == activeLocationId)
                              ? activeLocationId
                              : (nodes.isNotEmpty ? nodes.first.id : null),
                          items: nodes.map((n) {
                            return DropdownMenuItem(
                              value: n.id,
                              child: Text(
                                '${n.name} (${n.category})',
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              ref.read(mappingProvider.notifier).setVisitorLocation(val);
                              spatialNotifier.setCurrentLocationById(val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          // Floating Elevator-Style Vertical Floor Switcher & Zoom Controls
          Positioned(
            right: 14,
            top: 54,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Vertical Floor Switcher Column
                if (floors.isNotEmpty)
                  Material(
                    color: AppColors.surface,
                    elevation: AppSpacing.elevationMedium,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(AppSpacing.radiusMd),
                              ),
                            ),
                            child: const Text(
                              'LEVEL',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                          for (final floor in floors.reversed) ...[
                            InkWell(
                              onTap: () => spatialNotifier.selectFloor(floor),
                              child: Container(
                                width: 38,
                                height: 32,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: activeFloor?.id == floor.id
                                      ? AppColors.primary
                                      : Colors.transparent,
                                ),
                                child: Text(
                                  floor.floorNumber <= 0 || (floor.floorNumber == 1 && floor.name.toLowerCase().contains('ground'))
                                      ? 'G'
                                      : 'F${floor.floorNumber}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: activeFloor?.id == floor.id
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                            if (floor != floors.first)
                              const Divider(height: 1, color: AppColors.border),
                          ],
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 10),

                // Map Floating Controls (Zoom + Fit to Screen + Layer toggles)
                Material(
                  color: AppColors.surface,
                  elevation: AppSpacing.elevationMedium,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add, size: 20),
                          tooltip: 'Zoom In',
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                          onPressed: _zoomIn,
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        IconButton(
                          icon: const Icon(Icons.remove, size: 20),
                          tooltip: 'Zoom Out',
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                          onPressed: _zoomOut,
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        IconButton(
                          icon: const Icon(Icons.center_focus_strong, size: 20, color: AppColors.primary),
                          tooltip: 'Reset View / Fit to Screen',
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                          onPressed: _resetView,
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        IconButton(
                          icon: Icon(
                            _showLabels ? Icons.label : Icons.label_off,
                            size: 18,
                            color: _showLabels ? AppColors.primary : AppColors.textMuted,
                          ),
                          tooltip: 'Toggle Node Labels',
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                          onPressed: () {
                            setState(() => _showLabels = !_showLabels);
                          },
                        ),
                      ],
                    ),
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

/// Node Details Inspector Bottom Sheet Panel
class _NodeInspectorCard extends StatelessWidget {
  final NodeModel node;
  final bool isStartLocation;
  final bool isDestination;
  final VoidCallback onSetStart;
  final VoidCallback onSetDestination;
  final VoidCallback onDismiss;

  const _NodeInspectorCard({
    required this.node,
    required this.isStartLocation,
    required this.isDestination,
    required this.onSetStart,
    required this.onSetDestination,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final (Color badgeColor, IconData categoryIcon) = switch (node.category) {
      'elevator' => (AppColors.nodeElevator, Icons.elevator),
      'stairs' => (AppColors.nodeStairs, Icons.stairs),
      'emergency_exit' => (AppColors.nodeExit, Icons.exit_to_app),
      'entrance' => (Colors.teal, Icons.door_front_door),
      'room' || 'laboratory' => (AppColors.primary, Icons.meeting_room),
      _ => (AppColors.textSecondary, Icons.place),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(categoryIcon, color: badgeColor, size: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node.name,
                      style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Text(
                          node.category.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                          ),
                        ),
                        const Text(' • ', style: TextStyle(color: Colors.grey)),
                        Text(
                          'X: ${node.x.toStringAsFixed(1)}m, Y: ${node.y.toStringAsFixed(1)}m',
                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                        ),
                        const Text(' • ', style: TextStyle(color: Colors.grey)),
                        Icon(
                          node.accessible ? Icons.accessible : Icons.not_accessible,
                          size: 12,
                          color: node.accessible ? AppColors.success : AppColors.warning,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                tooltip: 'Dismiss',
                onPressed: onDismiss,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(
                    isStartLocation ? Icons.check : Icons.my_location,
                    size: 16,
                  ),
                  label: Text(
                    isStartLocation ? 'Current Start' : 'Set as Start',
                    style: const TextStyle(fontSize: 11),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: onSetStart,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ElevatedButton.icon(
                  icon: Icon(
                    isDestination ? Icons.check : Icons.location_on,
                    size: 16,
                  ),
                  label: Text(
                    isDestination ? 'Destination' : 'Set Destination',
                    style: const TextStyle(fontSize: 11),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: onSetDestination,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
