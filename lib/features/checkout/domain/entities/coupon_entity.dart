// ignore_for_file: constant_identifier_names

import 'package:freezed_annotation/freezed_annotation.dart';

part 'coupon_entity.freezed.dart';

enum CouponDiscountType {
  PERCENTAGE,
  FLAT,
  CASHBACK,
  FREE_DELIVERY,
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
    // CASHBACK/FREE_DELIVERY coupons never reduce the bill (discountAmount
    // stays 0 for both, by backend design) — they produce a separate
    // effect instead, carried in these two fields.
    @Default(0) double cashbackAmount,
    @Default(false) bool freeDelivery,
  }) = _CouponEntity;
}
