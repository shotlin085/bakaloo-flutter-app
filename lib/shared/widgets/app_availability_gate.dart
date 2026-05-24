import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:rive/rive.dart';

import 'package:bakaloo_flutter_app/core/network/app_availability_provider.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';

class AppAvailabilityGate extends ConsumerWidget {
  const AppAvailabilityGate({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(appAvailabilityProvider);

    return Stack(
      children: <Widget>[
        child,
        if (status != AppAvailabilityStatus.online)
          Positioned.fill(
            child: _AvailabilityBlocker(
              status: status,
              onRetry: () {
                ref.read(appAvailabilityProvider.notifier).retry();
              },
            ),
          ),
      ],
    );
  }
}

class _AvailabilityBlocker extends StatelessWidget {
  const _AvailabilityBlocker({
    required this.status,
    required this.onRetry,
  });

  final AppAvailabilityStatus status;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isOffline = status == AppAvailabilityStatus.offline;
    final title = isOffline ? 'Connection lost' : 'Service unavailable';
    final actionLabel = isOffline ? 'Try to reconnect' : 'Try again';

    return Material(
      color: const Color(0xFFF3F3F3),
      child: _AvailabilityOverlay(
        title: title,
        actionLabel: actionLabel,
        onRetry: onRetry,
      ),
    );
  }
}

class _AvailabilityOverlay extends StatelessWidget {
  const _AvailabilityOverlay({
    required this.title,
    required this.actionLabel,
    required this.onRetry,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF3F3F3),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final animationSize = (constraints.maxWidth * 0.72).clamp(
              240.0,
              320.0,
            );

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Column(
                children: <Widget>[
                  const Spacer(flex: 2),
                  RepaintBoundary(
                    child: ClipRect(
                      child: SizedBox(
                        width: animationSize,
                        height: animationSize,
                        child: const RiveAnimation.asset(
                          'assets/animations/3679-7682-birdy.riv',
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 1),
                  Padding(
                    padding: EdgeInsets.only(bottom: 84.h),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.h1.copyWith(
                            fontSize: 24.sp,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF151515),
                            letterSpacing: -0.2,
                          ),
                        ),
                        Gap(6.h),
                        TextButton(
                          onPressed: onRetry,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF8A2BE2),
                            textStyle: AppTextStyles.buttonMedium.copyWith(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 6.h,
                            ),
                          ),
                          child: Text(actionLabel),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
