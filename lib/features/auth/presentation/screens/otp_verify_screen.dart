import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pinput/pinput.dart';

import 'package:bakaloo_flutter_app/core/security/screenshot_prevention.dart';
import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/utils/validators.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_gate_controller.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_state.dart';

class OtpVerifyScreen extends ConsumerStatefulWidget {
  const OtpVerifyScreen({
    required this.phone,
    super.key,
  });

  final String phone;

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _otpController = TextEditingController();
  late final AnimationController _shakeController;

  Timer? _timer;
  int _secondsRemaining = 60;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    unawaited(ScreenshotPrevention.enable());
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _startCountdown();
  }

  @override
  void dispose() {
    unawaited(ScreenshotPrevention.disable());
    _timer?.cancel();
    _shakeController.dispose();
    _otpController.dispose();
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

      if (next case AuthAuthenticated()) {
        unawaited(
          ref.read(authGateControllerProvider).consumeAndResume(context),
        );
        return;
      }

      if (next case AuthError(:final message)) {
        unawaited(_handleOtpError(message));
        return;
      }

      if (next case AuthOtpSent()) {
        _startCountdown();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('OTP sent successfully.')),
          );
      }
    });

    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState is AuthLoading;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final pinWidth = ((screenWidth - 84.w) / 6).clamp(44.0, 56.0);

    final defaultPinTheme = PinTheme(
      width: pinWidth,
      height: 58.h,
      textStyle: TextStyle(
        fontFamily: 'Poppins',
        color: AppColors.authTextWhite,
        fontSize: 22.sp,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        color: AppColors.authPurpleSurface,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: AppColors.authInputBorder.withAlpha(80),
          width: 1,
        ),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(
        color: AppColors.authPink,
        width: 1.8,
      ),
    );

    final errorPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(
        color: AppColors.errorRed,
        width: 1.8,
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.authPurpleDeep,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: AppColors.authTextWhite,
          title: Text(
            'Verify OTP',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.authTextWhite,
            ),
          ),
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppColors.authBgGradient),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(24.w, 10.h, 24.w, 32.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // ── Subtitle ──
                  Text(
                    'Enter the 6-digit code sent to',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w400,
                      color: AppColors.authTextMuted,
                      height: 1.5,
                    ),
                  ),
                  Gap(4.h),
                  Text(
                    _maskedPhone,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.authTextWhite,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 240.ms)
                      .slideX(begin: -0.03, end: 0),

                  Gap(8.h),
                  Text(
                    'This code helps us confirm that the number belongs to you.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w400,
                      color: AppColors.authTextMuted.withAlpha(180),
                      height: 1.5,
                    ),
                  ),

                  Gap(32.h),

                  // ── OTP Pinput ──
                  Center(
                    child: AnimatedBuilder(
                      animation: _shakeController,
                      builder: (BuildContext context, Widget? child) {
                        final offset = math.sin(
                                _shakeController.value * math.pi * 6,) *
                            10;
                        return Transform.translate(
                          offset: Offset(offset, 0),
                          child: child,
                        );
                      },
                      child: Pinput(
                        controller: _otpController,
                        length: 6,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        defaultPinTheme: defaultPinTheme,
                        focusedPinTheme: focusedPinTheme,
                        submittedPinTheme: defaultPinTheme,
                        errorPinTheme: errorPinTheme,
                        forceErrorState: _hasError,
                        errorText: _errorMessage,
                        errorTextStyle: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.authPink,
                        ),
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        onChanged: (String value) {
                          if (_hasError || _errorMessage != null) {
                            setState(() {
                              _hasError = false;
                              _errorMessage = null;
                            });
                          }
                        },
                        onCompleted: _submitOtp,
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 80.ms, duration: 280.ms)
                      .slideY(begin: 0.06, end: 0),

                  Gap(24.h),

                  // ── Resend timer / button ──
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 12.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.authPurpleSurface.withAlpha(120),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: AppColors.authInputBorder.withAlpha(60),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        PhosphorIcon(
                          _secondsRemaining > 0
                              ? PhosphorIcons.timer()
                              : PhosphorIcons.arrowClockwise(),
                          color: AppColors.authPink,
                          size: 18.sp,
                        ),
                        Gap(10.w),
                        Expanded(
                          child: _secondsRemaining > 0
                              ? Text(
                                  'Resend available in $_formattedCountdown',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.authTextMuted,
                                  ),
                                )
                              : GestureDetector(
                                  onTap: isLoading
                                      ? null
                                      : () {
                                          setState(() {
                                            _hasError = false;
                                            _errorMessage = null;
                                          });
                                          ref
                                              .read(
                                                authNotifierProvider
                                                    .notifier,
                                              )
                                              .sendOtp(widget.phone);
                                        },
                                  child: Text(
                                    'Resend OTP',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.authPink,
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),

                  Gap(28.h),

                  // ── Verify button ──
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
                        onPressed: isLoading
                            ? null
                            : () => _submitOtp(_otpController.text),
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
                                'Verify OTP',
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
                      .fadeIn(delay: 160.ms, duration: 280.ms)
                      .slideY(begin: 0.06, end: 0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _maskedPhone {
    if (widget.phone.length < 10) {
      return '+91 ${widget.phone}';
    }

    return '+91 ${widget.phone.substring(0, 2)}******${widget.phone.substring(8)}';
  }

  String get _formattedCountdown {
    final seconds = _secondsRemaining.toString().padLeft(2, '0');
    return '00:$seconds';
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() {
      _secondsRemaining = 60;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() {
          _secondsRemaining = 0;
        });
        return;
      }
      setState(() {
        _secondsRemaining -= 1;
      });
    });
  }

  Future<void> _handleOtpError(String message) async {
    setState(() {
      _hasError = true;
      _errorMessage = message;
    });
    await _shakeController.forward(from: 0);
  }

  void _submitOtp(String value) {
    final error = Validators.validateOtp(value);
    if (error != null) {
      unawaited(_handleOtpError(error));
      return;
    }

    ref.read(authNotifierProvider.notifier).verifyOtp(
          phone: widget.phone,
          otp: value,
        );
  }
}
