import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/models/node_model.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/app_text_field.dart';

/// Modal dialog for adding or editing an indoor node/location
/// Owner: Nishant (Phase 3 — Creator Workflow)
class NodeFormDialog extends StatefulWidget {
  final String floorId;
  final NodeModel? initialNode;
  final double? initialX;
  final double? initialY;
  final ValueChanged<NodeModel> onSave;
  final VoidCallback? onDelete;

  const NodeFormDialog({
    super.key,
    required this.floorId,
    this.initialNode,
    this.initialX,
    this.initialY,
    required this.onSave,
    this.onDelete,
  });

  static Future<void> show(
    BuildContext context, {
    required String floorId,
    NodeModel? initialNode,
    double? initialX,
    double? initialY,
    required ValueChanged<NodeModel> onSave,
    VoidCallback? onDelete,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => NodeFormDialog(
        floorId: floorId,
        initialNode: initialNode,
        initialX: initialX,
        initialY: initialY,
        onSave: onSave,
        onDelete: onDelete,
      ),
    );
  }

  @override
  State<NodeFormDialog> createState() => _NodeFormDialogState();
}

class _NodeFormDialogState extends State<NodeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _xController;
  late final TextEditingController _yController;
  late final TextEditingController _descController;
  late String _selectedCategory;
  late bool _isAccessible;

  static const List<Map<String, String>> _categories = [
    {'value': 'room', 'label': 'Room / Office / Lab'},
    {'value': 'corridor', 'label': 'Corridor Junction'},
    {'value': 'entrance', 'label': 'Entrance / Exit'},
    {'value': 'stair', 'label': 'Stairs'},
    {'value': 'lift', 'label': 'Elevator / Lift'},
    {'value': 'emergency_exit', 'label': 'Emergency Exit'},
    {'value': 'poi', 'label': 'Point of Interest (POI)'},
    {'value': 'restroom', 'label': 'Restroom'},
    {'value': 'laboratory', 'label': 'Laboratory'},
  ];

  @override
  void initState() {
    super.initState();
    final n = widget.initialNode;
    final defaultX = widget.initialX ?? 25.0;
    final defaultY = widget.initialY ?? 25.0;
    _nameController = TextEditingController(text: n?.name ?? '');
    _xController = TextEditingController(
      text: n != null ? n.x.toStringAsFixed(2) : defaultX.toStringAsFixed(2),
    );
    _yController = TextEditingController(
      text: n != null ? n.y.toStringAsFixed(2) : defaultY.toStringAsFixed(2),
    );
    _descController = TextEditingController(
      text: (n?.metadata['description'] as String?) ?? '',
    );
    _selectedCategory = n?.category ?? 'room';
    _isAccessible = n?.accessible ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _xController.dispose();
    _yController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;

    final x = double.tryParse(_xController.text.trim()) ?? 0.0;
    final y = double.tryParse(_yController.text.trim()) ?? 0.0;
    final id = widget.initialNode?.id ??
        'node-$_selectedCategory-${DateTime.now().millisecondsSinceEpoch % 10000}';

    final node = NodeModel(
      id: id,
      name: _nameController.text.trim(),
      category: _selectedCategory,
      floorId: widget.floorId,
      x: x,
      y: y,
      accessible: _isAccessible,
      metadata: {
        if (_descController.text.trim().isNotEmpty)
          'description': _descController.text.trim(),
        'updatedAt': DateTime.now().toIso8601String(),
      },
    );

    widget.onSave(node);
    Navigator.of(context).pop();
  }

  Future<void> _handleDelete() async {
    final confirmed = await AppDialogs.showConfirm(
      context,
      title: 'Delete Location',
      message:
          'Are you sure you want to delete "${widget.initialNode?.name}"? All connecting edges will also be removed safely.',
      confirmLabel: 'Delete',
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
    final isEditing = widget.initialNode != null;

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
                      isEditing ? 'Edit Location' : 'Add Location',
                      style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (isEditing && widget.onDelete != null)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.error),
                        tooltip: 'Delete Node',
                        onPressed: _handleDelete,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _nameController,
                  label: 'Location Name *',
                  hint: 'e.g. Robotics Lab 101',
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Category / Node Type',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                  ),
                  items: _categories.map((c) {
                    return DropdownMenuItem(
                      value: c['value']!,
                      child: Text(c['label']!),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCategory = val);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _xController,
                        label: 'Coordinate X (m) *',
                        hint: '0.0',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) => (v == null || double.tryParse(v.trim()) == null)
                            ? 'Number required'
                            : null,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppTextField(
                        controller: _yController,
                        label: 'Coordinate Y (m) *',
                        hint: '0.0',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) => (v == null || double.tryParse(v.trim()) == null)
                            ? 'Number required'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                SwitchListTile(
                  title: const Text('Wheelchair Accessible'),
                  subtitle: const Text('Step-free access for mobility assistance'),
                  value: _isAccessible,
                  activeThumbColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setState(() => _isAccessible = val),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _descController,
                  label: 'Description / Instructions',
                  hint: 'Optional notes for visitors',
                  maxLines: 2,
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
                        label: isEditing ? 'Update Location' : 'Add Location',
                        icon: isEditing ? Icons.check : Icons.add_location_alt,
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
