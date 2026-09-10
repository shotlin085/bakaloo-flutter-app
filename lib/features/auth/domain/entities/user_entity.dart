import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_entity.freezed.dart';

@freezed
abstract class UserEntity with _$UserEntity {
  const UserEntity._();

  const factory UserEntity({
    required String id,
    required String phone,
    required String role,
    String? name,
    String? email,
    String? avatarUrl,
    int? loyaltyPoints,
    String? referralCode,
    /// 'PENDING' | 'APPROVED' | 'REJECTED' | 'SUSPENDED' — null when the
    /// user has never applied for a business (B2B/wholesale) account.
    String? b2bStatus,
    /// Whether the customer has switched B2B pricing on. Only meaningful
    /// (and only ever true) when [b2bStatus] is 'APPROVED'.
    bool? b2bEnabled,
  }) = _UserEntity;

  /// Eligible to switch wholesale pricing on — an approved business account.
  /// Never trust [b2bEnabled] alone; a SUSPENDED/REJECTED account must not
  /// be treated as wholesale-eligible even if it was enabled before.
  bool get isBusinessAccountApproved => b2bStatus == 'APPROVED';
}

class AuthEntity {
  const AuthEntity({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final UserEntity user;
}

class TokenEntity {
  const TokenEntity({
    required this.accessToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String refreshToken;
}
