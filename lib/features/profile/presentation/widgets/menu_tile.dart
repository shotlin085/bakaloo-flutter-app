import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';

class MenuTile extends StatelessWidget {
  const MenuTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.trailing,
    this.isDanger = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final tileColor = isDanger ? AppColors.errorRed : AppColors.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 52.h,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: <Widget>[
                PhosphorIcon(
                  icon,
                  size: 20.sp,
                  color: tileColor,
                ),
                Gap(14.w),
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w500,
                      color: tileColor,
                    ),
                  ),
                ),
                if (trailing != null) ...<Widget>[
                  trailing!,
                  Gap(10.w),
                ],
                PhosphorIcon(
                  PhosphorIcons.caretRight(),
                  size: 18.sp,
                  color:
                      isDanger ? AppColors.errorRed : AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
