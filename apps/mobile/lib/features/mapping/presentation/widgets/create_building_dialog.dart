import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/models/building_model.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';

/// Modal dialog for creating a new campus building
/// Owner: Nishant (Phase 3 — Creator Workflow)
class CreateBuildingDialog extends StatefulWidget {
  final BuildingModel? initialBuilding;
  final ValueChanged<BuildingModel> onSave;

  const CreateBuildingDialog({
    super.key,
    this.initialBuilding,
    required this.onSave,
  });

  static Future<BuildingModel?> show(
    BuildContext context, {
    BuildingModel? initialBuilding,
  }) {
    return showDialog<BuildingModel>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreateBuildingDialog(
        initialBuilding: initialBuilding,
        onSave: (building) => Navigator.of(context).pop(building),
      ),
    );
  }

  @override
  State<CreateBuildingDialog> createState() => _CreateBuildingDialogState();
}

class _CreateBuildingDialogState extends State<CreateBuildingDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _idController;
  late final TextEditingController _addressController;
  late final TextEditingController _categoryController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  late final TextEditingController _descController;

  @override
  void initState() {
    super.initState();
    final b = widget.initialBuilding;
    _nameController = TextEditingController(text: b?.name ?? '');
    _idController = TextEditingController(
      text: b?.id ?? 'bld-${DateTime.now().millisecondsSinceEpoch % 10000}',
    );
    _addressController = TextEditingController(text: b?.address ?? 'Campus Grounds');
    _categoryController = TextEditingController(text: b?.category ?? 'academic');
    _latController = TextEditingController(text: (b?.latitude ?? 12.8406).toString());
    _lngController = TextEditingController(text: (b?.longitude ?? 80.1534).toString());
    _descController = TextEditingController(
      text: (b?.metadata['description'] as String?) ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    _addressController.dispose();
    _categoryController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;

    final lat = double.tryParse(_latController.text.trim()) ?? 12.8406;
    final lng = double.tryParse(_lngController.text.trim()) ?? 80.1534;

    final building = BuildingModel(
      id: _idController.text.trim(),
      name: _nameController.text.trim(),
      address: _addressController.text.trim(),
      category: _categoryController.text.trim(),
      latitude: lat,
      longitude: lng,
      metadata: {
        if (_descController.text.trim().isNotEmpty)
          'description': _descController.text.trim(),
        'createdBy': 'Creator',
      },
    );

    widget.onSave(building);
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
                        color: AppColors.primarySubtle,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: const Icon(Icons.apartment, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Create Campus Building',
                      style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _nameController,
                  label: 'Building Name *',
                  hint: 'e.g. Science & Technology Block',
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Building name is required' : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _idController,
                  label: 'Building Identifier / Code *',
                  hint: 'e.g. bld-stb-01',
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Identifier is required' : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _addressController,
                  label: 'Postal / Campus Address',
                  hint: 'e.g. North Quad, University Avenue',
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _categoryController,
                  label: 'Category',
                  hint: 'academic, facility, administrative, etc.',
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _latController,
                        label: 'Latitude',
                        hint: '12.8406',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppTextField(
                        controller: _lngController,
                        label: 'Longitude',
                        hint: '80.1534',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _descController,
                  label: 'Description / Notes',
                  hint: 'Optional notes or building details',
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
                        label: 'Save Building',
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
