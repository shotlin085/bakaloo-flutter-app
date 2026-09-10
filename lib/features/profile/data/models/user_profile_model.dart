import 'package:bakaloo_flutter_app/features/auth/domain/entities/user_entity.dart';

class UserProfileModel {
  const UserProfileModel({
    required this.id,
    required this.phone,
    required this.role,
    this.name,
    this.email,
    this.avatarUrl,
    this.birthday,
    this.loyaltyPoints,
    this.referralCode,
    this.b2bStatus,
    this.b2bEnabled,
  });

  final String id;
  final String phone;
  final String role;
  final String? name;
  final String? email;
  final String? avatarUrl;
  final DateTime? birthday;
  final int? loyaltyPoints;
  final String? referralCode;
  final String? b2bStatus;
  final bool? b2bEnabled;

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: _readString(json, <String>['id']),
      phone: _readString(json, <String>['phone']),
      role: _readString(json, <String>['role'], fallback: 'CUSTOMER'),
      name: _readNullableString(json, <String>['name']),
      email: _readNullableString(json, <String>['email']),
      avatarUrl: _readNullableString(
        json,
        <String>['avatarUrl', 'avatar_url'],
      ),
      birthday: _readDateTime(json, <String>['birthday']),
      loyaltyPoints: _readInt(
        json,
        <String>['loyaltyPoints', 'loyalty_points'],
      ),
      referralCode: _readNullableString(
        json,
        <String>['referralCode', 'referral_code'],
      ),
      b2bStatus: _readNullableString(json, <String>['b2bStatus', 'b2b_status']),
      b2bEnabled: _readBool(json, <String>['b2bEnabled', 'b2b_enabled']),
    );
  }

  UserProfileModel copyWith({
    String? id,
    String? phone,
    String? role,
    String? name,
    String? email,
    String? avatarUrl,
    DateTime? birthday,
    int? loyaltyPoints,
    String? referralCode,
    String? b2bStatus,
    bool? b2bEnabled,
    bool clearAvatar = false,
    bool clearBirthday = false,
  }) {
    return UserProfileModel(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: clearAvatar ? null : avatarUrl ?? this.avatarUrl,
      birthday: clearBirthday ? null : birthday ?? this.birthday,
      loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
      referralCode: referralCode ?? this.referralCode,
      b2bStatus: b2bStatus ?? this.b2bStatus,
      b2bEnabled: b2bEnabled ?? this.b2bEnabled,
    );
  }

  UserEntity toEntity() {
    return UserEntity(
      id: id,
      phone: phone,
      role: role,
      name: name,
      email: email,
      avatarUrl: avatarUrl,
      loyaltyPoints: loyaltyPoints,
      referralCode: referralCode,
      b2bStatus: b2bStatus,
      b2bEnabled: b2bEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'phone': phone,
      'role': role,
      'name': name,
      'email': email,
      'avatar_url': avatarUrl,
      'birthday': _formatBirthday(birthday),
      'loyalty_points': loyaltyPoints,
      'referral_code': referralCode,
      'b2b_status': b2bStatus,
      'b2b_enabled': b2bEnabled,
    }..removeWhere((key, value) => value == null);
  }

  static String _readString(
    Map<String, dynamic> json,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return fallback;
  }

  static String? _readNullableString(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  static int? _readInt(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String && value.trim().isNotEmpty) {
        final parsed = int.tryParse(value.trim());
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  static bool? _readBool(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value is bool) {
        return value;
      }
    }
    return null;
  }

  static DateTime? _readDateTime(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        final parsed = DateTime.tryParse(value.trim());
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  static String? _formatBirthday(DateTime? value) {
    if (value == null) {
      return null;
    }
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
