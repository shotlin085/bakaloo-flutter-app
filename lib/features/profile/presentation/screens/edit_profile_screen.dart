import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/features/profile/presentation/providers/profile_provider.dart';
import 'package:bakaloo_flutter_app/routing/app_router.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  DateTime? _birthday;
  bool _initialized = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileData = ref.watch(profileProvider).asData?.value;
    final fallbackUser = ref.watch(currentUserProvider);
    final user = profileData?.user ?? fallbackUser;

    if (!_initialized && user != null) {
      _nameController.text = user.name ?? '';
      _emailController.text = user.email ?? '';
      _birthday = profileData?.birthday;
      _initialized = true;
    }

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text('Edit Profile', style: AppTextStyles.h2),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: PhosphorIcon(
            PhosphorIcons.caretLeft,
            color: AppColors.textPrimary,
            size: 22.sp,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 30.h),
          children: <Widget>[
            Text(
              'Name',
              style: AppTextStyles.labelLarge.copyWith(
                fontSize: 13.sp,
                color: AppColors.textSecondary,
              ),
            ),
            Gap(6.h),
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: _inputDecoration('Enter your name'),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.length < 2) {
                  return 'Name must be at least 2 characters';
                }
                return null;
              },
            ),
            Gap(14.h),
            Text(
              'Email',
              style: AppTextStyles.labelLarge.copyWith(
                fontSize: 13.sp,
                color: AppColors.textSecondary,
              ),
            ),
            Gap(6.h),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              decoration: _inputDecoration('Enter your email'),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) {
                  return null;
                }
                final valid = RegExp(
                  r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
                ).hasMatch(text);
                if (!valid) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
            Gap(14.h),
            Text(
              'Birthday',
              style: AppTextStyles.labelLarge.copyWith(
                fontSize: 13.sp,
                color: AppColors.textSecondary,
              ),
            ),
            Gap(6.h),
            InkWell(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd.r),
              onTap: _pickBirthday,
              child: InputDecorator(
                decoration: _inputDecoration('Select birthday'),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _birthday == null
                            ? 'Select birthday'
                            : DateFormat('dd MMM yyyy').format(_birthday!),
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: _birthday == null
                              ? AppColors.textTertiary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    PhosphorIcon(
                      PhosphorIcons.calendarDots,
                      size: 20.sp,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            Gap(22.h),
            SizedBox(
              height: 50.h,
              child: FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? SizedBox(
                        height: 20.r,
                        width: 20.r,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppColors.textOnGreen,
                        ),
                      )
                    : Text(
                        'Save',
                        style: AppTextStyles.buttonLarge.copyWith(
                          color: AppColors.textOnGreen,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary),
      filled: true,
      fillColor: AppColors.bgCard,
      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd.r),
        borderSide: const BorderSide(color: AppColors.borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd.r),
        borderSide: const BorderSide(color: AppColors.borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd.r),
        borderSide: const BorderSide(
          color: AppColors.primaryGreen,
          width: 1.2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd.r),
        borderSide: const BorderSide(color: AppColors.errorRed),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd.r),
        borderSide: const BorderSide(color: AppColors.errorRed, width: 1.2),
      ),
    );
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(1950),
      lastDate: now,
    );
    if (selected == null) {
      return;
    }
    setState(() => _birthday = selected);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    final result = await ref.read(profileProvider.notifier).updateProfile(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          birthday: _birthday,
        );

    if (!mounted) {
      return;
    }

    setState(() => _isSaving = false);

    if (!result.isSuccess && result.failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.failure!.message)),
      );
      return;
    }

    context.pop(true);
  }
}
