import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/state/auth_state.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';

/// Production Registration Screen
/// Owner: Nishant (Presentation Shell)
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  UserRole _selectedRole = UserRole.creator;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authProvider.notifier).register(
          name: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
          role: _selectedRole,
        );

    if (success && mounted) {
      Navigator.of(context).pushReplacementNamed(AppRouter.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(authProvider.notifier).clearError();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Join ${AppStrings.appName}',
                  style: AppTypography.headlineLarge.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Map indoor spaces, create spatial graph edges, and navigate buildings effortlessly.',
                  style: AppTypography.bodySmall,
                ),
                const SizedBox(height: AppSpacing.lg),

                // Error Banner
                if (authState.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.errorSubtle,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      border: Border.all(color: AppColors.error),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, size: 20, color: AppColors.error),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            authState.errorMessage!,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Full Name
                AppTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  hint: 'e.g. Alex Morgan',
                  prefixIcon: const Icon(Icons.person_outline, size: 20),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                // Email
                AppTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  hint: 'e.g. user@institution.edu',
                  prefixIcon: const Icon(Icons.email_outlined, size: 20),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                // Password
                AppTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: 'At least 6 characters',
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleRegister(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // Role Selector
                Text(
                  'Select Your Role',
                  style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.xs),
                SegmentedButton<UserRole>(
                  segments: const [
                    ButtonSegment(
                      value: UserRole.creator,
                      label: Text('Creator / Staff'),
                      icon: Icon(Icons.edit_location_alt_outlined),
                    ),
                    ButtonSegment(
                      value: UserRole.visitor,
                      label: Text('Visitor'),
                      icon: Icon(Icons.person_pin_circle_outlined),
                    ),
                  ],
                  selected: {_selectedRole},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _selectedRole = selection.first;
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.xl),

                // Register Button
                AppButton(
                  label: 'Create Account',
                  isFullWidth: true,
                  isLoading: authState.isLoading,
                  onPressed: _handleRegister,
                ),
                const SizedBox(height: AppSpacing.lg),

                // Back to Login
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already registered? ',
                      style: AppTypography.bodySmall,
                    ),
                    GestureDetector(
                      onTap: () {
                        ref.read(authProvider.notifier).clearError();
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        'Sign In',
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
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
