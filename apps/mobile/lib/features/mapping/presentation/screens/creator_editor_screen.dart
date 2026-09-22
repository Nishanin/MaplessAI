import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/models/edge_model.dart';
import '../../../../core/models/node_model.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/state/auth_state.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_status_chip.dart';
import '../../domain/map_draft_model.dart';
import '../../state/creator_controller.dart';
import '../../state/walkthrough_controller.dart';
import '../../state/walkthrough_state.dart';
import '../widgets/edge_form_dialog.dart';
import '../widgets/indoor_canvas.dart';
import '../widgets/node_form_dialog.dart';
import '../widgets/semantic_metadata_dialog.dart';
import '../widgets/validation_summary_card.dart';

/// Interactive Map Editor and Session View for Map Authors
/// Owner: Nishant (Phase 3 & Phase 6 — Creator Map Editor with Sensor-Assisted Walkthrough)
class CreatorEditorScreen extends ConsumerStatefulWidget {
  const CreatorEditorScreen({super.key});

  @override
  ConsumerState<CreatorEditorScreen> createState() => _CreatorEditorScreenState();
}

class _CreatorEditorScreenState extends ConsumerState<CreatorEditorScreen> {
  bool _showValidationSheet = false;

  void _handleAddNode({bool atSensorPosition = false}) {
    final draft = ref.read(creatorProvider).activeDraft;
    if (draft == null) return;

    final wtState = ref.read(walkthroughProvider);
    final useSensorCoords = atSensorPosition || wtState.isRecording || wtState.isPaused;

    NodeFormDialog.show(
      context,
      floorId: draft.floor.id,
      initialX: useSensorCoords ? wtState.currentPosition.dx : null,
      initialY: useSensorCoords ? wtState.currentPosition.dy : null,
      onSave: (node) {
        ref.read(creatorProvider.notifier).addNode(node);
        ref.read(walkthroughProvider.notifier).onNodePlaced(node);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Node "${node.name}" added at (${node.x.toStringAsFixed(1)}m, ${node.y.toStringAsFixed(1)}m).',
            ),
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

  void _handleAcceptCandidateConnection(CandidateConnection candidate) {
    final draft = ref.read(creatorProvider).activeDraft;
    if (draft == null) return;

    final edge = EdgeModel(
      id: 'edge-${candidate.fromNode.id}-${candidate.toNode.id}',
      startNodeId: candidate.fromNode.id,
      endNodeId: candidate.toNode.id,
      distance: candidate.distance,
      bearing: candidate.bearing,
      accessible: candidate.fromNode.accessible && candidate.toNode.accessible,
      blocked: false,
    );

    final success = ref.read(creatorProvider.notifier).connectNodes(edge);
    ref.read(walkthroughProvider.notifier).dismissCandidateConnection();

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Connected "${candidate.fromNode.name}" ➔ "${candidate.toNode.name}" (${candidate.distance.toStringAsFixed(1)}m).',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _handleResetOrigin() async {
    final confirmed = await AppDialogs.showConfirm(
      context,
      title: 'Reset Mapping Origin?',
      message:
          'This will re-zero relative sensor coordinates to (0.0, 0.0) and restart the walked path trace. Existing mapped locations will remain preserved.',
      confirmLabel: 'Reset Origin',
      icon: Icons.refresh,
    );

    if (confirmed == true && mounted) {
      ref.read(walkthroughProvider.notifier).resetOrigin();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Walkthrough origin reset to (0.0, 0.0).'),
          duration: Duration(seconds: 1),
        ),
      );
    }
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

  Widget _buildWalkthroughHud(
    BuildContext context,
    WalkthroughState wtState,
    WalkthroughController wtNotifier,
  ) {
    final AppStatusType statusType = switch (wtState.status) {
      WalkthroughStatus.recording => AppStatusType.active,
      WalkthroughStatus.paused => AppStatusType.warning,
      WalkthroughStatus.stopped => AppStatusType.draft,
      WalkthroughStatus.idle => AppStatusType.info,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        border: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Telemetry and Status Header Row
          Row(
            children: [
              AppStatusChip(
                label: wtState.status.name.toUpperCase(),
                status: statusType,
                isCompact: true,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _TelemetryChip(
                        icon: Icons.directions_walk,
                        label: '${wtState.stepCount} steps',
                      ),
                      const SizedBox(width: 6),
                      _TelemetryChip(
                        icon: Icons.straighten,
                        label: '${wtState.distance.toStringAsFixed(1)}m',
                      ),
                      const SizedBox(width: 6),
                      _TelemetryChip(
                        icon: Icons.explore,
                        label: '${wtState.currentHeading.toStringAsFixed(0)}°',
                      ),
                      const SizedBox(width: 6),
                      _TelemetryChip(
                        icon: Icons.my_location,
                        label:
                            '(${wtState.currentPosition.dx.toStringAsFixed(1)}m, ${wtState.currentPosition.dy.toStringAsFixed(1)}m)',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Walkthrough Control Buttons (Responsive Wrap)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (wtState.isIdle)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: const Size(0, 32),
                  ),
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: const Text('Start Walkthrough', style: TextStyle(fontSize: 12)),
                  onPressed: () => wtNotifier.startWalkthrough(),
                ),
              if (wtState.isRecording) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: const Size(0, 32),
                  ),
                  icon: const Icon(Icons.add_location_alt, size: 16),
                  label: const Text('Add Location Here', style: TextStyle(fontSize: 12)),
                  onPressed: () => _handleAddNode(atSensorPosition: true),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(0, 32),
                  ),
                  icon: const Icon(Icons.pause, size: 14),
                  label: const Text('Pause', style: TextStyle(fontSize: 11)),
                  onPressed: () => wtNotifier.pauseWalkthrough(),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(0, 32),
                  ),
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('Reset Origin', style: TextStyle(fontSize: 11)),
                  onPressed: _handleResetOrigin,
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(0, 32),
                  ),
                  icon: const Icon(Icons.stop, size: 14, color: AppColors.error),
                  label: const Text('Stop', style: TextStyle(fontSize: 11)),
                  onPressed: () => wtNotifier.stopWalkthrough(),
                ),
              ],
              if (wtState.isPaused) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: const Size(0, 32),
                  ),
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: const Text('Resume', style: TextStyle(fontSize: 12)),
                  onPressed: () => wtNotifier.resumeWalkthrough(),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: const Size(0, 32),
                  ),
                  icon: const Icon(Icons.add_location_alt, size: 16),
                  label: const Text('Add Location Here', style: TextStyle(fontSize: 12)),
                  onPressed: () => _handleAddNode(atSensorPosition: true),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(0, 32),
                  ),
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('Reset Origin', style: TextStyle(fontSize: 11)),
                  onPressed: _handleResetOrigin,
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(0, 32),
                  ),
                  icon: const Icon(Icons.stop, size: 14, color: AppColors.error),
                  label: const Text('Stop', style: TextStyle(fontSize: 11)),
                  onPressed: () => wtNotifier.stopWalkthrough(),
                ),
              ],
              if (wtState.isStopped) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: const Size(0, 32),
                  ),
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: const Text('New Walkthrough', style: TextStyle(fontSize: 12)),
                  onPressed: () => wtNotifier.startWalkthrough(),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(0, 32),
                  ),
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('Reset Origin', style: TextStyle(fontSize: 11)),
                  onPressed: _handleResetOrigin,
                ),
              ],
            ],
          ),

          // Informational Warning if Sensor Degraded
          if (wtState.errorMessage != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.amber.shade900),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      wtState.errorMessage!,
                      style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    if (authState.user != null && authState.user!.role == UserRole.visitor) {
      return AppScaffold(
        title: 'Map Editor',
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 56, color: AppColors.textMuted),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Creator Access Only',
                  style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'This workspace is reserved for authorized map creators and facility staff. Visitors can explore published maps and navigate routes.',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Return to Visitor Navigation',
                  icon: Icons.explore,
                  onPressed: () => Navigator.of(context).pushReplacementNamed(AppRouter.home),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final creatorState = ref.watch(creatorProvider);
    final creatorNotifier = ref.read(creatorProvider.notifier);
    final draft = creatorState.activeDraft;

    final wtState = ref.watch(walkthroughProvider);
    final wtNotifier = ref.read(walkthroughProvider.notifier);

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
    final candidateConn = wtState.candidateConnection;

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

          // Phase 6 Walkthrough HUD Bar
          _buildWalkthroughHud(context, wtState, wtNotifier),

          // Auto-Connect Candidate Connection Banner (Phase 6)
          if (candidateConn != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.teal.shade50,
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 18, color: Colors.teal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Connect "${candidateConn.fromNode.name}" ➔ "${candidateConn.toNode.name}" (${candidateConn.distance.toStringAsFixed(1)}m, ${candidateConn.bearing.toStringAsFixed(0)}°)?',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () => _handleAcceptCandidateConnection(candidateConn),
                    child: const Text('Connect'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => wtNotifier.dismissCandidateConnection(),
                  ),
                ],
              ),
            ),

          // Connect mode banner (manual linking)
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
                  creatorMappingPosition: wtState.currentPosition,
                  creatorHeading: wtState.currentHeading,
                  creatorWalkedPath: wtState.recordedPath,
                  isRecordingWalkthrough: wtState.isRecording,
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

          // Editor Toolbar Action Bar (Manual Fallback Always Functional)
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
                    onPressed: () => _handleAddNode(atSensorPosition: false),
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

class _TelemetryChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TelemetryChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
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
              Expanded(
                child: Text(
                  'Selected: ${node.name} (${node.category})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${node.x.toStringAsFixed(1)}m, ${node.y.toStringAsFixed(1)}m)',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
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
                IconButton(
                  tooltip: 'Delete Node',
                  icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                  onPressed: onDelete,
                ),
              ],
            ),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edge: ${edge.startNodeId} ➔ ${edge.endNodeId}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
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
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(width: 4),
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
