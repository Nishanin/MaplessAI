import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/models/floor_model.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';

/// Modal dialog for creating a new floor in a building
/// Owner: Nishant (Phase 3 — Creator Workflow)
class CreateFloorDialog extends StatefulWidget {
  final String buildingId;
  final FloorModel? initialFloor;
  final ValueChanged<FloorModel> onSave;

  const CreateFloorDialog({
    super.key,
    required this.buildingId,
    this.initialFloor,
    required this.onSave,
  });

  static Future<FloorModel?> show(
    BuildContext context, {
    required String buildingId,
    FloorModel? initialFloor,
  }) {
    return showDialog<FloorModel>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreateFloorDialog(
        buildingId: buildingId,
        initialFloor: initialFloor,
        onSave: (floor) => Navigator.of(context).pop(floor),
      ),
    );
  }

  @override
  State<CreateFloorDialog> createState() => _CreateFloorDialogState();
}

class _CreateFloorDialogState extends State<CreateFloorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _numberController;
  late final TextEditingController _elevationController;

  @override
  void initState() {
    super.initState();
    final f = widget.initialFloor;
    _nameController = TextEditingController(text: f?.name ?? '');
    _numberController = TextEditingController(text: (f?.floorNumber ?? 1).toString());
    _elevationController = TextEditingController(text: (f?.elevation ?? 0.0).toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    _elevationController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;

    final floorNum = int.tryParse(_numberController.text.trim()) ?? 1;
    final elevation = double.tryParse(_elevationController.text.trim()) ?? 0.0;
    final floorId = 'flr-${widget.buildingId}-$floorNum';

    final floor = FloorModel(
      id: floorId,
      buildingId: widget.buildingId,
      floorNumber: floorNum,
      name: _nameController.text.trim(),
      elevation: elevation,
      metadata: {'createdBy': 'Creator'},
    );

    widget.onSave(floor);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
      child: Container(
        width: 400,
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
                        color: AppColors.primarySubtle,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: const Icon(Icons.layers, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Create Floor',
                      style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _nameController,
                  label: 'Floor Label *',
                  hint: 'e.g. Ground Floor, Level 2',
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Floor label is required' : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _numberController,
                        label: 'Floor Number *',
                        hint: '1',
                        keyboardType: TextInputType.number,
                        validator: (v) => (v == null || int.tryParse(v.trim()) == null)
                            ? 'Valid integer required'
                            : null,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppTextField(
                        controller: _elevationController,
                        label: 'Elevation (m)',
                        hint: '0.0',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
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
                        label: 'Save Floor',
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
