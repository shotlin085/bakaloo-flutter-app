import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:bakaloo_flutter_app/core/notifications/fcm_service.dart';
import 'package:bakaloo_flutter_app/core/theme/app_theme.dart';
import 'package:bakaloo_flutter_app/routing/app_router.dart';
import 'package:bakaloo_flutter_app/shared/providers/theme_provider.dart';
import 'package:bakaloo_flutter_app/shared/widgets/app_availability_gate.dart';
import 'package:bakaloo_flutter_app/shared/widgets/app_route_loading_gate.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(initializeFcmProvider);
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (BuildContext context, Widget? child) {
        return MaterialApp.router(
          theme: AppTheme.lightTheme,
          themeMode: themeMode,
          routerConfig: router,
          debugShowCheckedModeBanner: false,
          builder: (BuildContext context, Widget? child) {
            final textScaleFactor = MediaQuery.of(context)
                .textScaler
                .scale(1)
                .clamp(0.8, 1.2)
                .toDouble();
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScaleFactor),
              ),
              child: AppAvailabilityGate(
                child: AppRouteLoadingGate(
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
