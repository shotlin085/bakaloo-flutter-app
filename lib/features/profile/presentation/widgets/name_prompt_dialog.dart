import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/core/utils/app_toast.dart';
import 'package:bakaloo_flutter_app/features/profile/presentation/providers/profile_provider.dart';

/// One-time "what's your name?" popup shown on Home when the logged-in
/// user has no name on file yet (OTP-only signup never asks for one).
/// Reappears on a later app open if dismissed without saving — the gate is
/// simply "does the profile have a name", not a one-shot "seen it" flag.
Future<void> showNamePromptDialog(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) => const _NamePromptDialog(),
  );
}

class _NamePromptDialog extends ConsumerStatefulWidget {
  const _NamePromptDialog();

  @override
  ConsumerState<_NamePromptDialog> createState() => _NamePromptDialogState();
}

class _NamePromptDialogState extends ConsumerState<_NamePromptDialog> {
  // Matches the app's actual brand accent (auth screens, bottom nav) — not
  // exposed via AppColors, which only has the green used for cart/delivery
  // CTAs, so it's defined locally here same as those other call sites do.
  static const Color _brandPurple = Color(0xFF6C4DFF);

  final TextEditingController _nameController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSaving = false;
  String? _errorText;

  @override
  void dispose() {
    _nameController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Please enter your name');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    final result = await ref.read(profileProvider.notifier).updateProfile(
          name: name,
        );

    if (!mounted) return;

    if (result.isSuccess) {
      Navigator.of(context).pop();
      AppToast.show(context, '👋 Thanks, $name!', type: ToastType.success);
    } else {
      setState(() {
        _isSaving = false;
        _errorText = result.failure?.message ?? 'Could not save your name.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(horizontal: 28.w),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24.w, 28.h, 24.w, 20.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 56.w,
                height: 56.w,
                decoration: BoxDecoration(
                  color: _brandPurple.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: PhosphorIcon(
                    PhosphorIcons.userCircleFill,
                    size: 30.sp,
                    color: _brandPurple,
                  ),
                ),
              ),
            ),
            Gap(16.h),
            Text(
              "What's your name?",
              textAlign: TextAlign.center,
              style: AppTextStyles.h2,
            ),
            Gap(6.h),
            Text(
              "We'll use this to personalize your orders and greet you\naround the app.",
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            Gap(20.h),
            TextField(
              controller: _nameController,
              focusNode: _focusNode,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              maxLength: 60,
              onSubmitted: (_) => _save(),
              onChanged: (_) {
                if (_errorText != null) setState(() => _errorText = null);
              },
              style: AppTextStyles.bodyLarge,
              decoration: InputDecoration(
                hintText: 'e.g. Priya Sharma',
                counterText: '',
                errorText: _errorText,
                filled: true,
                fillColor: const Color(0xFFF0F4F8),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 14.h,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                  borderSide: const BorderSide(
                    color: _brandPurple,
                    width: 1.2,
                  ),
                ),
              ),
            ),
            Gap(18.h),
            SizedBox(
              height: 50.h,
              child: FilledButton(
                onPressed: _isSaving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: _brandPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusMd,
                    ),
                  ),
                ),
                child: _isSaving
                    ? SizedBox(
                        width: 20.w,
                        height: 20.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        'Save',
                        style: AppTextStyles.buttonLarge.copyWith(
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            Gap(6.h),
            TextButton(
              onPressed: _isSaving
                  ? null
                  : () => Navigator.of(context).pop(),
              child: Text(
                'Maybe later',
                style: AppTextStyles.buttonMedium.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
