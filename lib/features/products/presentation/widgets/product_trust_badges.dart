import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/shared/widgets/trust_badge_card.dart';

class ProductTrustBadges extends StatelessWidget {
  const ProductTrustBadges({
    required this.product,
    this.onBrandTap,
    super.key,
  });

  final ProductEntity product;
  final VoidCallback? onBrandTap;

  @override
  Widget build(BuildContext context) {
    final brandLabel = product.brandDisplay.isNotEmpty
        ? 'More from ${product.brandDisplay}'
        : 'More from Brand';

    return Container(
      width: double.infinity,
      color: const Color(0xFFF5F5F5),
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (product.hasNoReturn)
            TrustBadgeCard(
              icon: _IconBadge(
                icon: PhosphorIcons.package(),
              ),
              title: 'No Exchange or Return',
              subtitle:
                  'This item is not eligible for exchange or return after delivery.',
            ),
          if (product.isAuthentic)
            TrustBadgeCard(
              icon: _IconBadge(
                icon: PhosphorIcons.shieldCheck(),
              ),
              title: '100% Authentic',
              subtitle:
                  'Sourced from trusted partners with quality checks before dispatch.',
            ),
          TrustBadgeCard(
            icon: _BrandBadge(brandLogoUrl: product.brandLogoUrl),
            title: brandLabel,
            subtitle:
                'Explore more products from the same brand and similar picks.',
            onTap: onBrandTap,
          ),
        ],
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({
    required this.icon,
  });

  final PhosphorIconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Center(
        child: PhosphorIcon(
          icon,
          size: 24.sp,
          color: const Color(0xFF1A1A1A),
        ),
      ),
    );
  }
}

class _BrandBadge extends StatelessWidget {
  const _BrandBadge({
    required this.brandLogoUrl,
  });

  final String? brandLogoUrl;

  @override
  Widget build(BuildContext context) {
    if ((brandLogoUrl ?? '').isNotEmpty) {
      return Center(
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: brandLogoUrl!,
            width: 36.w,
            height: 36.w,
            fit: BoxFit.cover,
            memCacheWidth: 108,
            memCacheHeight: 108,
            fadeInDuration: Duration.zero,
            placeholder: (context, url) => Container(
              width: 36.w,
              height: 36.w,
              decoration: const BoxDecoration(
                color: Color(0xFFF5F5F5),
                shape: BoxShape.circle,
              ),
            ),
            errorWidget: (context, url, error) => const _BrandFallback(),
          ),
        ),
      );
    }

    return const _BrandFallback();
  }
}

class _BrandFallback extends StatelessWidget {
  const _BrandFallback();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36.w,
        height: 36.w,
        decoration: const BoxDecoration(
          color: Color(0xFFF5F5F5),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: PhosphorIcon(
            PhosphorIcons.storefront(),
            size: 22.sp,
            color: const Color(0xFF1A1A1A),
          ),
        ),
      ),
    );
  }
}
