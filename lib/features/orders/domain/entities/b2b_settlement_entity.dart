import 'package:freezed_annotation/freezed_annotation.dart';

part 'b2b_settlement_entity.freezed.dart';

/// One manually-recorded payment-collection entry against a "Place Order"
/// B2B credit order — e.g. ₹200 cash today, ₹500 UPI next week, each its
/// own row rather than a single running total.
@freezed
abstract class B2BSettlementEntity with _$B2BSettlementEntity {
  const factory B2BSettlementEntity({
    required String id,
    required String method,
    required double amount,
    required DateTime createdAt,
    String? note,
  }) = _B2BSettlementEntity;
}
