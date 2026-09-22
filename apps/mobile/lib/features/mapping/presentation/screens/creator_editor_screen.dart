import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/models/edge_model.dart';
import '../../../../core/models/node_model.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_status_chip.dart';
import '../../domain/map_draft_model.dart';
import '../../state/creator_controller.dart';
import '../widgets/edge_form_dialog.dart';
import '../widgets/indoor_canvas.dart';
import '../widgets/node_form_dialog.dart';
import '../widgets/semantic_metadata_dialog.dart';
import '../widgets/validation_summary_card.dart';

/// Interactive Map Editor and Session View for Map Authors
/// Owner: Nishant (Phase 3 — Creator Map Editor)
class CreatorEditorScreen extends ConsumerStatefulWidget {
  const CreatorEditorScreen({super.key});

  @override
  ConsumerState<CreatorEditorScreen> createState() => _CreatorEditorScreenState();
}

class _CreatorEditorScreenState extends ConsumerState<CreatorEditorScreen> {
  bool _showValidationSheet = false;

  void _handleAddNode() {
    final draft = ref.read(creatorProvider).activeDraft;
    if (draft == null) return;

    NodeFormDialog.show(
      context,
      floorId: draft.floor.id,
      onSave: (node) {
        ref.read(creatorProvider.notifier).addNode(node);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Node "${node.name}" added.'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
    );
  }

  void _handleConnectNodes() {
    final draft = ref.read(creatorProvider).activeDraft;
    if (draft == null || draft.nodes.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least two locations before connecting edges.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final source = ref.read(creatorProvider).connectSourceNode ??
        ref.read(creatorProvider).selectedNode;

    EdgeFormDialog.show(
      context,
      nodes: draft.nodes,
      defaultStartNodeId: source?.id,
      onSave: (edge) {
        ref.read(creatorProvider.notifier).connectNodes(edge);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection created.'),
            duration: Duration(seconds: 1),
          ),
        );
      },
    );
  }

  void _handleValidate() {
    ref.read(creatorProvider.notifier).validateCurrentDraft();
    setState(() => _showValidationSheet = true);
  }

  void _handleSaveDraft() async {
    final success = await ref.read(creatorProvider.notifier).saveCurrentDraft();
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draft saved locally.'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final creatorState = ref.watch(creatorProvider);
    final creatorNotifier = ref.read(creatorProvider.notifier);
    final draft = creatorState.activeDraft;

    if (draft == null) {
      return AppScaffold(
        title: 'Map Editor',
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.map_outlined, size: 64, color: AppColors.textMuted),
              const SizedBox(height: AppSpacing.md),
              const Text('No active mapping session', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Go to Creator Dashboard',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      );
    }

    final selectedNode = creatorState.selectedNode;
    final selectedEdge = creatorState.selectedEdge;
    final hasValidation = creatorState.validationResult != null;

    final AppStatusType lifecycleStatusType = switch (draft.lifecycleState) {
      MapLifecycleState.draft => AppStatusType.info,
      MapLifecycleState.validated => AppStatusType.active,
      MapLifecycleState.published => AppStatusType.active,
      MapLifecycleState.failed => AppStatusType.error,
    };

    return AppScaffold(
      title: 'Mapping Session',
      actions: [
        IconButton(
          tooltip: 'Save Draft',
          icon: const Icon(Icons.save_outlined, color: AppColors.primary),
          onPressed: _handleSaveDraft,
        ),
        IconButton(
          tooltip: 'Preview Map',
          icon: const Icon(Icons.visibility_outlined, color: AppColors.primary),
          onPressed: () => Navigator.pushNamed(context, AppRouter.creatorPreview),
        ),
      ],
      body: Column(
        children: [
          // Session Header Info Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${draft.building.name} • ${draft.floor.name}',
                        style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${draft.nodes.length} Nodes • ${draft.edges.length} Connections',
                        style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                AppStatusChip(
                  label: draft.lifecycleState.name.toUpperCase(),
                  status: lifecycleStatusType,
                  isCompact: true,
                ),
              ],
            ),
          ),

          // Connect mode banner
          if (creatorState.connectSourceNode != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.amber.shade100,
              child: Row(
                children: [
                  const Icon(Icons.alt_route, size: 18, color: Colors.brown),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Connecting from "${creatorState.connectSourceNode!.name}"... Tap another node or tap Connect.',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    onPressed: () => creatorNotifier.setConnectSourceNode(null),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),

          // 2D Interactive Map Canvas
          Expanded(
            child: Stack(
              children: [
                IndoorCanvas(
                  nodes: draft.nodes,
                  edges: draft.edges,
                  selectedNodeId: selectedNode?.id,
                  onNodeTapped: (node) {
                    if (creatorState.connectSourceNode != null &&
                        creatorState.connectSourceNode!.id != node.id) {
                      // Trigger connect dialog with pre-selected source and target
                      EdgeFormDialog.show(
                        context,
                        nodes: draft.nodes,
                        defaultStartNodeId: creatorState.connectSourceNode!.id,
                        onSave: (edge) => creatorNotifier.connectNodes(edge),
                      );
                      creatorNotifier.setConnectSourceNode(null);
                    } else {
                      creatorNotifier.selectNode(node);
                    }
                  },
                ),

                // Validation Sheet Overlay (if active)
                if (_showValidationSheet && hasValidation)
                  Positioned(
                    top: 8,
                    left: 12,
                    right: 12,
                    child: Stack(
                      children: [
                        ValidationSummaryCard(
                          result: creatorState.validationResult!,
                          onRevalidate: _handleValidate,
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(() => _showValidationSheet = false),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Selected Entity Inspector Card
          if (selectedNode != null)
            _NodeInspector(
              node: selectedNode,
              onEdit: () {
                NodeFormDialog.show(
                  context,
                  floorId: draft.floor.id,
                  initialNode: selectedNode,
                  onSave: (n) => creatorNotifier.updateNode(n),
                  onDelete: () => creatorNotifier.deleteNode(selectedNode.id),
                );
              },
              onDelete: () => creatorNotifier.deleteNode(selectedNode.id),
              onConnectFrom: () => creatorNotifier.setConnectSourceNode(selectedNode),
              onAttachMetadata: () {
                final existingMeta = draft.metadata
                    .where((m) => m.entityId == selectedNode.id)
                    .firstOrNull;
                SemanticMetadataDialog.show(
                  context,
                  entityId: selectedNode.id,
                  entityType: 'node',
                  entityLabel: selectedNode.name,
                  initialMetadata: existingMeta,
                  onSave: (m) => creatorNotifier.addOrUpdateMetadata(m),
                );
              },
            ),

          if (selectedEdge != null)
            _EdgeInspector(
              edge: selectedEdge,
              onToggleBlocked: () => creatorNotifier.toggleEdgeBlocked(selectedEdge.id),
              onDelete: () => creatorNotifier.deleteEdge(selectedEdge.id),
            ),

          // Editor Toolbar Action Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                    label: const Text('Add Node'),
                    onPressed: _handleAddNode,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.alt_route, size: 18),
                    label: const Text('Connect'),
                    onPressed: _handleConnectNodes,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.verified_outlined, size: 18),
                    label: const Text('Validate'),
                    onPressed: _handleValidate,
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

class _NodeInspector extends StatelessWidget {
  final NodeModel node;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onConnectFrom;
  final VoidCallback onAttachMetadata;

  const _NodeInspector({
    required this.node,
    required this.onEdit,
    required this.onDelete,
    required this.onConnectFrom,
    required this.onAttachMetadata,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AppColors.primarySubtle,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Selected: ${node.name} (${node.category})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '(${node.x.toStringAsFixed(1)}m, ${node.y.toStringAsFixed(1)}m)',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              TextButton.icon(
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Edit'),
                onPressed: onEdit,
              ),
              TextButton.icon(
                icon: const Icon(Icons.alt_route, size: 16),
                label: const Text('Connect From'),
                onPressed: onConnectFrom,
              ),
              TextButton.icon(
                icon: const Icon(Icons.label_outline, size: 16),
                label: const Text('Metadata'),
                onPressed: onAttachMetadata,
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Delete Node',
                icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EdgeInspector extends StatelessWidget {
  final EdgeModel edge;
  final VoidCallback onToggleBlocked;
  final VoidCallback onDelete;

  const _EdgeInspector({
    required this.edge,
    required this.onToggleBlocked,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: edge.blocked ? AppColors.errorSubtle : Colors.grey.shade100,
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edge: ${edge.startNodeId} ➔ ${edge.endNodeId}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                '${edge.distance.toStringAsFixed(1)}m • ${edge.bearing.toStringAsFixed(1)}° • ${edge.blocked ? "BLOCKED" : "UNBLOCKED"}',
                style: TextStyle(
                  fontSize: 12,
                  color: edge.blocked ? AppColors.error : AppColors.textSecondary,
                  fontWeight: edge.blocked ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
          Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: edge.blocked ? AppColors.success : AppColors.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                icon: Icon(edge.blocked ? Icons.lock_open : Icons.block, size: 16),
                label: Text(edge.blocked ? 'Unblock' : 'Block'),
                onPressed: onToggleBlocked,
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Delete Edge',
                icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
