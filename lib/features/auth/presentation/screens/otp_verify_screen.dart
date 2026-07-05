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
  static const String _bgAsset =
      'assets/images/bakaloo-otp-background-illustration.png';
  static const Color _brandPurple = Color(0xFF6C4DFF);
  static const Color _headingColor = Color(0xFF2D1B69);
  static const Color _boxBorder = Color(0xFFE4DFF2);
  static const Color _pillBg = Color(0xFFF4F2FA);
  static const LinearGradient _buttonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: <Color>[Color(0xFF8B5CF6), Color(0xFF6C4DFF)],
  );

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
    final pinWidth = ((screenWidth - 88.w) / 6).clamp(44.0, 56.0);

    final defaultPinTheme = PinTheme(
      width: pinWidth,
      height: 58.h,
      textStyle: TextStyle(
        fontFamily: 'Poppins',
        color: _headingColor,
        fontSize: 22.sp,
        fontWeight: FontWeight.w700,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: _boxBorder,
          width: 1.4,
        ),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      color: Colors.white,
      border: Border.all(
        color: _brandPurple,
        width: 1.8,
      ),
    );

    final errorPinTheme = defaultPinTheme.copyDecorationWith(
      color: Colors.white,
      border: Border.all(
        color: AppColors.errorRed,
        width: 1.8,
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        // Fix #3: Do NOT resize when keyboard opens — prevents layout shift
        // that causes the background image to zoom/jump when OTP box is tapped.
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: <Widget>[
            // ── Full-screen illustration background ──
            // Fix #1: Show image from top without any negative translate shift.
            // Use BoxFit.fitWidth so the image fills the width and shows from
            // the top — no cropping of the branding/logo area.
            Positioned.fill(
              child: Image.asset(
                _bgAsset,
                fit: BoxFit.fitWidth,
                alignment: Alignment.topCenter,
              ),
            ),

            // ── Back button ──
            Positioned(
              top: MediaQuery.paddingOf(context).top + 4.h,
              left: 8.w,
              child: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: _headingColor,
                  size: 20.sp,
                ),
              ),
            ),

            // ── Heading overlay (sits in the empty band under the logo) ──
            Positioned(
              top: MediaQuery.sizeOf(context).height * 0.185,
              left: 24.w,
              right: 24.w,
              child: Column(
                children: <Widget>[
                  Text(
                    'Verify your number',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w800,
                      color: _headingColor,
                      height: 1.2,
                    ),
                  ),
                  Gap(8.h),
                  Text(
                    'Enter the 6-digit code sent to',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  Gap(2.h),
                  Text(
                    _maskedPhone,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w700,
                      color: _headingColor,
                    ),
                  ),
                  Gap(6.h),
                  Text(
                    'This code helps us confirm that\nthe number belongs to you.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textTertiary,
                      height: 1.45,
                    ),
                  ),
                ],
              )
                  .animate()
                  .fadeIn(duration: 260.ms)
                  .slideY(begin: -0.04, end: 0),
            ),

            // ── Bottom code-entry sheet ──
            // Fix #3 (continued): Use AnimatedPadding driven by the keyboard
            // viewInsets so the sheet slides UP with the keyboard smoothly
            // without the background image distorting.
            Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(28.r),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 20.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'Enter 6-digit code',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                          color: _headingColor,
                        ),
                      ),

                      Gap(16.h),

                      // ── OTP Pinput ──
                      AnimatedBuilder(
                        animation: _shakeController,
                        builder: (BuildContext context, Widget? child) {
                          final offset = math.sin(
                                _shakeController.value * math.pi * 6,
                              ) *
                              10;
                          return Transform.translate(
                            offset: Offset(offset, 0),
                            child: child,
                          );
                        },
                        child: Pinput(
                          controller: _otpController,
                          length: 6,
                          // Fix #2: Do NOT autofocus — prevents keyboard from
                          // opening immediately and squeezing the OTP boxes.
                          // User taps a box to bring up the keyboard naturally.
                          autofocus: false,
                          keyboardType: TextInputType.number,
                          defaultPinTheme: defaultPinTheme,
                          focusedPinTheme: focusedPinTheme,
                          submittedPinTheme: defaultPinTheme,
                          errorPinTheme: errorPinTheme,
                          forceErrorState: _hasError,
                          errorText: _errorMessage,
                          cursor: Container(
                            width: 2,
                            height: 26.h,
                            color: _brandPurple,
                          ),
                          errorTextStyle: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.errorRed,
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

                      Gap(18.h),

                      // ── Resend timer / button ──
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 12.h,
                        ),
                        decoration: BoxDecoration(
                          color: _pillBg,
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(color: _boxBorder),
                        ),
                        child: Row(
                          children: <Widget>[
                            PhosphorIcon(
                              _secondsRemaining > 0
                                  ? PhosphorIcons.arrowClockwise()
                                  : PhosphorIcons.arrowClockwise(),
                              color: _brandPurple,
                              size: 20.sp,
                            ),
                            Gap(12.w),
                            Expanded(
                              child: _secondsRemaining > 0
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          'Resend code',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.w700,
                                            color: _headingColor,
                                          ),
                                        ),
                                        Gap(1.h),
                                        Text.rich(
                                          TextSpan(
                                            text: 'You can resend the code in ',
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w400,
                                              color: AppColors.textSecondary,
                                            ),
                                            children: <InlineSpan>[
                                              TextSpan(
                                                text: _formattedCountdown,
                                                style: TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: 12.sp,
                                                  fontWeight: FontWeight.w700,
                                                  color: _brandPurple,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
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
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            'Resend code',
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.w700,
                                              color: _headingColor,
                                            ),
                                          ),
                                          Gap(1.h),
                                          Text(
                                            'Tap to send a new code',
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w600,
                                              color: _brandPurple,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),

                      Gap(18.h),

                      // ── Verify button ──
                      SizedBox(
                        width: double.infinity,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: _buttonGradient,
                            borderRadius: BorderRadius.circular(16.r),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: _brandPurple.withValues(alpha: 0.35),
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
                              foregroundColor: Colors.white,
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
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ),

                      Gap(16.h),

                      // ── Footer help ──
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            PhosphorIcon(
                              PhosphorIcons.shieldCheck(),
                              color: _brandPurple,
                              size: 15.sp,
                            ),
                            Gap(6.w),
                            Flexible(
                              child: Text.rich(
                                TextSpan(
                                  text:
                                      "Didn't receive the code? Check your SMS or ",
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12.sp,
                                    color: AppColors.textSecondary,
                                    height: 1.45,
                                  ),
                                  children: <InlineSpan>[
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.middle,
                                      child: GestureDetector(
                                        onTap: isLoading || _secondsRemaining > 0
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
                                          'try again.',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.w700,
                                            color: _brandPurple,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ), // closes AnimatedPadding
            ),  // closes Align
          ],
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
