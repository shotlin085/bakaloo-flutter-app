import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/utils/validators.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_gate_controller.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_state.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';

class PhoneEntryScreen extends ConsumerStatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  ConsumerState<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends ConsumerState<PhoneEntryScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  bool _hasInteracted = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authNotifierProvider, (
      AuthState? previous,
      AuthState next,
    ) {
      final route = ModalRoute.of(context);
      if (!mounted || !(route?.isCurrent ?? false)) {
        return;
      }

      if (next case AuthOtpSent(:final phone)) {
        context.push('${RouteNames.otp}?phone=$phone');
        return;
      }

      if (next case AuthAuthenticated()) {
        unawaited(
          ref.read(authGateControllerProvider).consumeAndResume(context),
        );
        return;
      }

      if (next case AuthError(:final message)) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    });

    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState is AuthLoading;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.authPurpleDeep,
        resizeToAvoidBottomInset: true,
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppColors.authBgGradient),
          child: SafeArea(
            child: Column(
              children: <Widget>[
                // ─── Scrollable content ───
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(24.w, 14.h, 24.w, 24.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // ── Skip button ──
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () => context.go(RouteNames.home),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 8.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.authSkipBg,
                                borderRadius: BorderRadius.circular(20.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    'Skip',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.authTextWhite,
                                    ),
                                  ),
                                  Gap(4.w),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.authTextWhite,
                                    size: 18.sp,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ).animate().fadeIn(duration: 220.ms),

                        Gap(36.h),

                        // ── Brand name ──
                        Text(
                          'bakaloo',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 42.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.authTextWhite,
                            height: 1.1,
                            letterSpacing: -0.5,
                          ),
                        )
                            .animate()
                            .fadeIn(duration: 300.ms)
                            .slideX(begin: -0.05, end: 0),

                        Gap(12.h),

                        // ── Tagline ──
                        Text(
                          'Fresh Groceries\nDelivered in Minutes',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 26.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.authTextWhite,
                            height: 1.25,
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 80.ms, duration: 300.ms)
                            .slideX(begin: -0.05, end: 0),

                        Gap(56.h),

                        // ── Phone input pill ──
                        Form(
                          key: _formKey,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 6.h,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.authPurpleSurface,
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(
                                color: AppColors.authInputBorder.withAlpha(80),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: <Widget>[
                                Text(
                                  '+91',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.authTextWhite,
                                  ),
                                ),
                                Gap(12.w),
                                Container(
                                  width: 1,
                                  height: 28.h,
                                  color: AppColors.authInputBorder
                                      .withAlpha(100),
                                ),
                                Gap(12.w),
                                Expanded(
                                  child: TextFormField(
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    textInputAction: TextInputAction.done,
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.authTextWhite,
                                      height: 1.3,
                                    ),
                                    cursorColor: AppColors.authPink,
                                    inputFormatters: <TextInputFormatter>[
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(10),
                                    ],
                                    validator: Validators.validatePhone,
                                    autovalidateMode:
                                        AutovalidateMode.disabled,
                                    onChanged: (_) {
                                      if (!_hasInteracted) {
                                        setState(() {
                                          _hasInteracted = true;
                                        });
                                        return;
                                      }
                                      setState(() {});
                                    },
                                    onFieldSubmitted: (_) => _submitPhone(),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      errorBorder: InputBorder.none,
                                      focusedErrorBorder: InputBorder.none,
                                      filled: false,
                                      hintText: 'Enter Phone Number',
                                      hintStyle: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w400,
                                        color: AppColors.authTextMuted,
                                      ),
                                      contentPadding: EdgeInsets.symmetric(
                                        vertical: 12.h,
                                      ),
                                      errorStyle: const TextStyle(
                                        height: 0,
                                        fontSize: 0,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 140.ms, duration: 280.ms)
                            .slideY(begin: 0.06, end: 0),

                        // ── Validation error ──
                        if (_hasInteracted &&
                            Validators.validatePhone(
                                  _phoneController.text.trim(),
                                ) !=
                                null) ...<Widget>[
                          Gap(10.h),
                          Text(
                            Validators.validatePhone(
                                  _phoneController.text.trim(),
                                ) ??
                                '',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.authPink,
                            ),
                          ),
                        ],

                        Gap(20.h),

                        // ── Continue button ──
                        SizedBox(
                          width: double.infinity,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: AppColors.authBtnGradient,
                              borderRadius: BorderRadius.circular(16.r),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: AppColors.authPink.withAlpha(80),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: isLoading ? null : _submitPhone,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: AppColors.authTextWhite,
                                minimumSize: Size.fromHeight(56.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16.r),
                                ),
                              ),
                              child: isLoading
                                  ? SizedBox(
                                      width: 22.w,
                                      height: 22.w,
                                      child: const CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'Continue',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.authTextWhite,
                                      ),
                                    ),
                            ),
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 200.ms, duration: 280.ms)
                            .slideY(begin: 0.06, end: 0),
                      ],
                    ),
                  ),
                ),

                // ─── Terms footer (always bottom-anchored) ───
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 32.w, vertical: 16.h),
                  child: Text.rich(
                    TextSpan(
                      text: 'By continuing, you agree to our\n',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.sp,
                        color: AppColors.authTextMuted,
                        height: 1.6,
                      ),
                      children: <InlineSpan>[
                        TextSpan(
                          text: 'Terms of Use',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.sp,
                            color: AppColors.authTextLink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: ' & ',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.sp,
                            color: AppColors.authTextMuted,
                          ),
                        ),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.sp,
                            color: AppColors.authTextLink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ).animate().fadeIn(delay: 260.ms, duration: 240.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submitPhone() {
    setState(() {
      _hasInteracted = true;
    });

    final normalizedPhone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    ref.read(authNotifierProvider.notifier).sendOtp(normalizedPhone);
  }
}
