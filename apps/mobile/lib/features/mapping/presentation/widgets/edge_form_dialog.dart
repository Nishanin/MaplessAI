import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/models/edge_model.dart';
import '../../../../core/models/node_model.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/app_text_field.dart';

/// Modal dialog for creating or editing a topological connection/edge
/// Owner: Nishant (Phase 3 — Creator Workflow)
class EdgeFormDialog extends StatefulWidget {
  final List<NodeModel> nodes;
  final EdgeModel? initialEdge;
  final String? defaultStartNodeId;
  final ValueChanged<EdgeModel> onSave;
  final VoidCallback? onDelete;

  const EdgeFormDialog({
    super.key,
    required this.nodes,
    this.initialEdge,
    this.defaultStartNodeId,
    required this.onSave,
    this.onDelete,
  });

  static Future<void> show(
    BuildContext context, {
    required List<NodeModel> nodes,
    EdgeModel? initialEdge,
    String? defaultStartNodeId,
    required ValueChanged<EdgeModel> onSave,
    VoidCallback? onDelete,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => EdgeFormDialog(
        nodes: nodes,
        initialEdge: initialEdge,
        defaultStartNodeId: defaultStartNodeId,
        onSave: onSave,
        onDelete: onDelete,
      ),
    );
  }

  @override
  State<EdgeFormDialog> createState() => _EdgeFormDialogState();
}

class _EdgeFormDialogState extends State<EdgeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late String? _startNodeId;
  late String? _endNodeId;
  late final TextEditingController _distanceController;
  late final TextEditingController _bearingController;
  late bool _isAccessible;
  late bool _isBlocked;

  @override
  void initState() {
    super.initState();
    final e = widget.initialEdge;
    final validNodeIds = widget.nodes.map((n) => n.id).toSet();

    _startNodeId = e?.startNodeId ??
        (widget.defaultStartNodeId != null && validNodeIds.contains(widget.defaultStartNodeId)
            ? widget.defaultStartNodeId
            : (widget.nodes.isNotEmpty ? widget.nodes.first.id : null));

    _endNodeId = e?.endNodeId ??
        (widget.nodes.length > 1
            ? widget.nodes.firstWhere((n) => n.id != _startNodeId, orElse: () => widget.nodes[1]).id
            : null);

    _distanceController = TextEditingController(text: (e?.distance ?? 10.0).toStringAsFixed(1));
    _bearingController = TextEditingController(text: (e?.bearing ?? 90.0).toStringAsFixed(1));
    _isAccessible = e?.accessible ?? true;
    _isBlocked = e?.blocked ?? false;

    if (e == null) {
      _autoCalculateGeometry();
    }
  }

  @override
  void dispose() {
    _distanceController.dispose();
    _bearingController.dispose();
    super.dispose();
  }

  void _autoCalculateGeometry() {
    if (_startNodeId == null || _endNodeId == null || _startNodeId == _endNodeId) return;

    final start = widget.nodes.where((n) => n.id == _startNodeId).firstOrNull;
    final end = widget.nodes.where((n) => n.id == _endNodeId).firstOrNull;
    if (start == null || end == null) return;

    final dx = end.x - start.x;
    final dy = end.y - start.y;
    final dist = math.sqrt(dx * dx + dy * dy);

    // Calculate clockwise compass bearing in degrees
    var rad = math.atan2(dx, dy);
    var deg = rad * (180 / math.pi);
    if (deg < 0) deg += 360;

    _distanceController.text = dist.toStringAsFixed(1);
    _bearingController.text = deg.toStringAsFixed(1);
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;
    if (_startNodeId == null || _endNodeId == null) return;

    if (_startNodeId == _endNodeId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Start and destination nodes cannot be the same.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final dist = double.tryParse(_distanceController.text.trim()) ?? 1.0;
    final bearing = double.tryParse(_bearingController.text.trim()) ?? 0.0;
    final id = widget.initialEdge?.id ??
        'edge-$_startNodeId-$_endNodeId-${DateTime.now().millisecondsSinceEpoch % 1000}';

    final edge = EdgeModel(
      id: id,
      startNodeId: _startNodeId!,
      endNodeId: _endNodeId!,
      distance: dist,
      bearing: bearing,
      accessible: _isAccessible,
      blocked: _isBlocked,
      metadata: {
        'updatedAt': DateTime.now().toIso8601String(),
      },
    );

    widget.onSave(edge);
    Navigator.of(context).pop();
  }

  Future<void> _handleDelete() async {
    final confirmed = await AppDialogs.showConfirm(
      context,
      title: 'Delete Connection',
      message: 'Are you sure you want to delete this edge between nodes?',
      confirmLabel: 'Delete Edge',
      isDestructive: true,
      icon: Icons.delete_outline,
    );

    if (confirmed == true && mounted) {
      widget.onDelete?.call();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialEdge != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing ? 'Edit Connection' : 'Connect Locations',
                      style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (isEditing && widget.onDelete != null)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.error),
                        tooltip: 'Delete Edge',
                        onPressed: _handleDelete,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Source Node Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _startNodeId,
                  decoration: InputDecoration(
                    labelText: 'Start Location (Source) *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                  ),
                  items: widget.nodes.map((n) {
                    return DropdownMenuItem(
                      value: n.id,
                      child: Text('${n.name} (${n.category})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _startNodeId = val;
                      _autoCalculateGeometry();
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.sm),

                // Destination Node Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _endNodeId,
                  decoration: InputDecoration(
                    labelText: 'Destination Location (Target) *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                  ),
                  items: widget.nodes.map((n) {
                    return DropdownMenuItem(
                      value: n.id,
                      child: Text('${n.name} (${n.category})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _endNodeId = val;
                      _autoCalculateGeometry();
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.sm),

                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _distanceController,
                        label: 'Distance (meters) *',
                        hint: '10.0',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) => (v == null || double.tryParse(v.trim()) == null)
                            ? 'Positive number'
                            : null,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppTextField(
                        controller: _bearingController,
                        label: 'Bearing (0-360°) *',
                        hint: '90.0',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          final num = double.tryParse(v ?? '');
                          if (num == null || num < 0 || num > 360) {
                            return '0 to 360';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),

                // Accessibility Switch
                SwitchListTile(
                  title: const Text('Wheelchair / Step-Free Accessible'),
                  subtitle: const Text('Ramp or flat hallway (no steps)'),
                  value: _isAccessible,
                  activeThumbColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setState(() => _isAccessible = val),
                ),

                // Blocked / Unblocked State Switch
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isBlocked ? AppColors.errorSubtle : AppColors.successSubtle,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(
                      color: _isBlocked ? AppColors.error : AppColors.success,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isBlocked ? Icons.block : Icons.check_circle_outline,
                            color: _isBlocked ? AppColors.error : AppColors.success,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isBlocked ? 'Connection BLOCKED' : 'Connection UNBLOCKED',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _isBlocked ? AppColors.error : AppColors.success,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                _isBlocked ? 'Temporarily closed / maintenance' : 'Open for transit',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: _isBlocked,
                        activeThumbColor: AppColors.error,
                        onChanged: (val) => setState(() => _isBlocked = val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Cancel',
                        variant: AppButtonVariant.outlined,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppButton(
                        label: isEditing ? 'Update Connection' : 'Create Edge',
                        icon: isEditing ? Icons.check : Icons.alt_route,
                        onPressed: _handleSubmit,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
