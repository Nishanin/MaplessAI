import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/models/semantic_metadata_model.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';

/// Modal dialog for authoring and editing semantic metadata
/// Owner: Nishant (Phase 3 — Creator Metadata Forms)
class SemanticMetadataDialog extends StatefulWidget {
  final String entityId;
  final String entityType; // 'node', 'edge', 'floor', 'building'
  final String entityLabel;
  final SemanticMetadataModel? initialMetadata;
  final ValueChanged<SemanticMetadataModel> onSave;

  const SemanticMetadataDialog({
    super.key,
    required this.entityId,
    this.entityType = 'node',
    required this.entityLabel,
    this.initialMetadata,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    required String entityId,
    String entityType = 'node',
    required String entityLabel,
    SemanticMetadataModel? initialMetadata,
    required ValueChanged<SemanticMetadataModel> onSave,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => SemanticMetadataDialog(
        entityId: entityId,
        entityType: entityType,
        entityLabel: entityLabel,
        initialMetadata: initialMetadata,
        onSave: onSave,
      ),
    );
  }

  @override
  State<SemanticMetadataDialog> createState() => _SemanticMetadataDialogState();
}

class _SemanticMetadataDialogState extends State<SemanticMetadataDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _tagsController;
  late final TextEditingController _aliasesController;
  late final TextEditingController _deptController;
  late final TextEditingController _hoursController;
  late final TextEditingController _capacityController;
  late final TextEditingController _descController;

  @override
  void initState() {
    super.initState();
    final m = widget.initialMetadata;
    _tagsController = TextEditingController(text: m?.tags.join(', ') ?? '');
    _aliasesController = TextEditingController(text: m?.aliases.join(', ') ?? '');
    _deptController = TextEditingController(text: m?.department ?? '');
    _hoursController = TextEditingController(text: m?.operationalHours ?? '08:00 - 18:00');
    _capacityController = TextEditingController(text: m?.capacity?.toString() ?? '');
    _descController = TextEditingController(text: m?.description ?? '');
  }

  @override
  void dispose() {
    _tagsController.dispose();
    _aliasesController.dispose();
    _deptController.dispose();
    _hoursController.dispose();
    _capacityController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;

    final tags = _tagsController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final aliases = _aliasesController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final cap = int.tryParse(_capacityController.text.trim());

    final metadata = SemanticMetadataModel(
      entityId: widget.entityId,
      entityType: widget.entityType,
      tags: tags,
      aliases: aliases,
      department: _deptController.text.trim().isEmpty ? null : _deptController.text.trim(),
      operationalHours: _hoursController.text.trim().isEmpty ? null : _hoursController.text.trim(),
      capacity: cap,
      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      customAttributes: widget.initialMetadata?.customAttributes ?? const {},
    );

    widget.onSave(metadata);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
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
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.secondarySubtle,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: const Icon(Icons.label, color: AppColors.secondary, size: 24),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Semantic Metadata',
                            style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Target: ${widget.entityLabel}',
                            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _tagsController,
                  label: 'Search Tags (comma separated)',
                  hint: 'e.g. computers, lab, printer, quiet zone',
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _aliasesController,
                  label: 'Aliases / Alternate Names (comma separated)',
                  hint: 'e.g. AI Lab, Room 101, Robotics Studio',
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _deptController,
                  label: 'Department / Unit',
                  hint: 'e.g. School of Computer Science',
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _hoursController,
                        label: 'Operational Hours',
                        hint: '08:00 - 18:00',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppTextField(
                        controller: _capacityController,
                        label: 'Capacity (Persons)',
                        hint: '30',
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v != null && v.trim().isNotEmpty) {
                            final num = int.tryParse(v.trim());
                            if (num == null || num < 0) return 'Valid positive integer';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _descController,
                  label: 'Detailed Description',
                  hint: 'Human instructions, facilities, or notes',
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
                        label: 'Save Metadata',
                        icon: Icons.check,
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
