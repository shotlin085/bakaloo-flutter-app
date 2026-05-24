import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';

class SkeletonLoader extends StatelessWidget {
  const SkeletonLoader({
    this.width,
    this.height = 16,
    this.radius = 12,
    this.shape = BoxShape.rectangle,
    super.key,
  });

  final double? width;
  final double height;
  final double radius;
  final BoxShape shape;

  const SkeletonLoader.circular({
    required double size,
    super.key,
  })  : width = size,
        height = size,
        radius = size / 2,
        shape = BoxShape.circle;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.bgSkeleton,
      highlightColor: AppColors.shimmerHighlight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.bgSkeleton,
          shape: shape,
          borderRadius:
              shape == BoxShape.circle ? null : BorderRadius.circular(radius),
        ),
      ),
    );
  }
}
