import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/constants/storage_keys.dart';
import 'package:bakaloo_flutter_app/core/di/providers.dart';
import 'package:bakaloo_flutter_app/core/socket/socket_service.dart';
import 'package:bakaloo_flutter_app/core/storage/hive_service.dart';
import 'package:bakaloo_flutter_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/auth/data/models/user_model.dart';
import 'package:bakaloo_flutter_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:bakaloo_flutter_app/features/auth/domain/entities/user_entity.dart';
import 'package:bakaloo_flutter_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:bakaloo_flutter_app/features/auth/domain/usecases/logout_usecase.dart';
import 'package:bakaloo_flutter_app/features/auth/domain/usecases/refresh_token_usecase.dart';
import 'package:bakaloo_flutter_app/features/auth/domain/usecases/send_otp_usecase.dart';
import 'package:bakaloo_flutter_app/features/auth/domain/usecases/verify_otp_usecase.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_state.dart';

part 'auth_notifier.g.dart';

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((Ref ref) {
  return AuthRemoteDataSource(ref.watch(apiClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((Ref ref) {
  return AuthRepositoryImpl(
    remoteDataSource: ref.watch(authRemoteDataSourceProvider),
    secureStorageService: ref.watch(secureStorageProvider),
  );
});

final sendOtpUseCaseProvider = Provider<SendOtpUseCase>((Ref ref) {
  return SendOtpUseCase(ref.watch(authRepositoryProvider));
});

final verifyOtpUseCaseProvider = Provider<VerifyOtpUseCase>((Ref ref) {
  return VerifyOtpUseCase(ref.watch(authRepositoryProvider));
});

final refreshTokenUseCaseProvider = Provider<RefreshTokenUseCase>((Ref ref) {
  return RefreshTokenUseCase(ref.watch(authRepositoryProvider));
});

final logoutUseCaseProvider = Provider<LogoutUseCase>((Ref ref) {
  return LogoutUseCase(ref.watch(authRepositoryProvider));
});

const authNotifierProvider = authProvider;
const authStateProvider = authNotifierProvider;

@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier {
  @override
  AuthState build() {
    ref.onDispose(() {
      ref.read(socketServiceProvider).disconnect();
    });
    return const AuthUnauthenticated();
  }

  Future<void> sendOtp(String phone) async {
    state = const AuthLoading();

    final result = await ref.read(sendOtpUseCaseProvider).call(phone);
    result.fold(
      (failure) => state = AuthError(message: failure.message),
      (_) => state = AuthOtpSent(phone: phone),
    );
  }

  Future<void> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    state = const AuthLoading();

    final result = await ref.read(verifyOtpUseCaseProvider).call(
          phone: phone,
          otp: otp,
        );

    await result.fold<Future<void>>(
      (failure) async {
        state = AuthError(message: failure.message);
      },
      (authEntity) async {
        ref.read(socketServiceProvider).connect(authEntity.accessToken);
        await _registerFcmToken();
        state = AuthAuthenticated(user: authEntity.user);

        // FIX: After successful login, trigger allocation auto-assign so that
        // real users with a saved default address get shop visibility immediately.
        // This runs in the background — authentication is already complete.
        // The home/product providers will pick up the new allocation on their
        // next read since the Redis cache is invalidated by the recompute.
        unawaited(_triggerAllocationAutoAssign());
      },
    );
  }

  Future<bool> refreshSession(String refreshToken) async {
    final result = await ref.read(refreshTokenUseCaseProvider).call(
          refreshToken,
        );

    return result.fold<Future<bool>>(
      (failure) async {
        state = const AuthUnauthenticated();
        return false;
      },
      (tokenEntity) async {
        await restoreSession(tokenEntity.accessToken);
        return true;
      },
    );
  }

  Future<void> restoreSession(String accessToken) async {
    final cachedUser = HiveService.userBox.get('user');
    final user = _userFromCache(cachedUser) ??
        _userFromClaims(JwtDecoder.decode(accessToken));

    state = AuthAuthenticated(user: user);
    ref.read(socketServiceProvider).connect(accessToken);

    // FIX: Also trigger auto-assign on session restore so that a user
    // who last opened the app before the fix now gets allocation resolved.
    unawaited(_triggerAllocationAutoAssign());
  }

  Future<void> logout() async {
    await ref.read(logoutUseCaseProvider).call();
    await ref.read(secureStorageProvider).clearAll();
    await HiveService.userBox.clear();
    await HiveService.settingsBox.delete(StorageKeys.lastFcmToken);
    ref.read(socketServiceProvider).disconnect();
    state = const AuthUnauthenticated();
  }

  UserEntity? _userFromCache(dynamic cachedUser) {
    if (cachedUser is! Map) {
      return null;
    }

    try {
      return UserModel.fromJson(
        Map<String, dynamic>.from(cachedUser),
      ).toEntity();
    } catch (_) {
      return null;
    }
  }

  UserEntity _userFromClaims(Map<String, dynamic> claims) {
    return UserEntity(
      id: _stringValue(claims, <String>['id', 'userId', 'sub']),
      phone: _stringValue(claims, <String>['phone']),
      name: _nullableValue(claims, <String>['name']),
      email: _nullableValue(claims, <String>['email']),
      avatarUrl: _nullableValue(claims, <String>['avatarUrl', 'avatar_url']),
      role: _stringValue(claims, <String>['role'], fallback: 'CUSTOMER'),
      loyaltyPoints:
          _intValue(claims, <String>['loyaltyPoints', 'loyalty_points']),
      referralCode:
          _nullableValue(claims, <String>['referralCode', 'referral_code']),
    );
  }

  String _stringValue(
    Map<String, dynamic> source,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = source[key];
      if (value is String && value.isNotEmpty) {
        return value;
      }
    }
    return fallback;
  }

  String? _nullableValue(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value is String && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  int? _intValue(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
    }
    return null;
  }

  /// FIX: After login or session restore, call POST /allocation/auto-assign
  /// to ensure the user has a shop allocation if they have a default address.
  /// This resolves the "Product not found" error for real users who logged in
  /// but never had allocation triggered.
  ///
  /// Fire-and-forget — auth state is already set before this runs.
  /// If it fails (network error, server error), the product service fallback
  /// (anonymous unscoped visibility) still allows browsing.
  Future<void> _triggerAllocationAutoAssign() async {
    try {
      await ref.read(dioClientProvider).post<dynamic>(
        ApiConstants.allocationAutoAssign,
      );
    } on DioException catch (e) {
      // 401 means token expired — ignore; the refresh interceptor will handle it.
      // Any other error is non-fatal: the anonymous fallback keeps products visible.
      if (e.response?.statusCode != 401) {
        // Silent — do not block auth or show error to user.
      }
    } catch (_) {
      // Non-fatal — ignore.
    }
  }

  Future<void> _registerFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        return;
      }

      final lastToken = HiveService.settingsBox.get(
        StorageKeys.lastFcmToken,
      ) as String?;
      if (lastToken == token) {
        return;
      }

      await ref.read(dioClientProvider).post<dynamic>(
        ApiConstants.notificationTokens,
        data: <String, dynamic>{
          'token': token,
          'platform': _platformName,
        },
      );

      await HiveService.settingsBox.put(StorageKeys.lastFcmToken, token);
    } on DioException {
      // FCM registration must not block authentication success.
    } catch (_) {
      // Ignore token registration failures and keep the session alive.
    }
  }

  String get _platformName {
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.android => 'android',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }
}
