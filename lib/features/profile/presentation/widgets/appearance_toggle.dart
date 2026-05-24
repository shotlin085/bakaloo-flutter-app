import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_shadows.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/shared/providers/theme_provider.dart';

class AppearanceToggle extends ConsumerWidget {
  const AppearanceToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg.r),
        boxShadow: const <BoxShadow>[AppShadows.cardShadow],
      ),
      child: Row(
        children: <Widget>[
          Text(
            'Appearance',
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          DropdownButtonHideUnderline(
            child: DropdownButton<ThemeMode>(
              value: themeMode,
              icon: PhosphorIcon(
                PhosphorIcons.caretDown(),
                size: 16.sp,
                color: AppColors.textSecondary,
              ),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd.r),
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13.sp,
              ),
              items: const <DropdownMenuItem<ThemeMode>>[
                DropdownMenuItem<ThemeMode>(
                  value: ThemeMode.light,
                  child: Text('LIGHT'),
                ),
                DropdownMenuItem<ThemeMode>(
                  value: ThemeMode.dark,
                  child: Text('DARK'),
                ),
                DropdownMenuItem<ThemeMode>(
                  value: ThemeMode.system,
                  child: Text('SYSTEM'),
                ),
              ],
              onChanged: (mode) {
                if (mode == null) {
                  return;
                }
                ref.read(themeModeProvider.notifier).setThemeMode(mode);
              },
            ),
          ),
        ],
      ),
    );
  }
}
