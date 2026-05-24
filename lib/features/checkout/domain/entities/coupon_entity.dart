// ignore_for_file: constant_identifier_names

import 'package:freezed_annotation/freezed_annotation.dart';

part 'coupon_entity.freezed.dart';

enum CouponDiscountType {
  PERCENTAGE,
  FLAT,
}

@freezed
abstract class CouponEntity with _$CouponEntity {
  const factory CouponEntity({
    required String code,
    required CouponDiscountType discountType,
    required double discountValue,
    required double discountAmount,
    required double minOrderAmount,
    required double maxDiscount,
    String? description,
    String? terms,
  }) = _CouponEntity;
}
