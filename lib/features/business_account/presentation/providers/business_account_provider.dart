import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/di/providers.dart';
import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/business_account/data/datasources/business_account_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/business_account/data/repositories/business_account_repository_impl.dart';
import 'package:bakaloo_flutter_app/features/business_account/domain/entities/business_account_entity.dart';
import 'package:bakaloo_flutter_app/features/business_account/domain/repositories/business_account_repository.dart';
import 'package:bakaloo_flutter_app/features/business_account/domain/usecases/apply.dart';
import 'package:bakaloo_flutter_app/features/business_account/domain/usecases/get_mine.dart';
import 'package:bakaloo_flutter_app/features/business_account/domain/usecases/toggle.dart';

part 'business_account_provider.g.dart';

class BusinessAccountActionResult {
  const BusinessAccountActionResult({this.failure});

  final Failure? failure;

  bool get isSuccess => failure == null;
}

final businessAccountRemoteDataSourceProvider =
    Provider<BusinessAccountRemoteDataSource>((Ref ref) {
  return BusinessAccountRemoteDataSource(ref.watch(apiClientProvider));
});

final businessAccountRepositoryProvider =
    Provider<BusinessAccountRepository>((Ref ref) {
  return BusinessAccountRepositoryImpl(
    remoteDataSource: ref.watch(businessAccountRemoteDataSourceProvider),
  );
});

final getMyBusinessAccountUseCaseProvider =
    Provider<GetMyBusinessAccountUseCase>((Ref ref) {
  return GetMyBusinessAccountUseCase(ref.watch(businessAccountRepositoryProvider));
});

final applyBusinessAccountUseCaseProvider =
    Provider<ApplyBusinessAccountUseCase>((Ref ref) {
  return ApplyBusinessAccountUseCase(ref.watch(businessAccountRepositoryProvider));
});

final toggleBusinessAccountUseCaseProvider =
    Provider<ToggleBusinessAccountUseCase>((Ref ref) {
  return ToggleBusinessAccountUseCase(ref.watch(businessAccountRepositoryProvider));
});

/// The caller's own business account — null when they've never applied.
/// Drives the Business Account screen and (via PriceModeNotifier) whether
/// the wholesale-pricing toggle is offered anywhere else in the app.
@riverpod
Future<BusinessAccountEntity?> myBusinessAccount(Ref ref) async {
  final result = await ref.read(getMyBusinessAccountUseCaseProvider).call();
  return result.fold(
    (failure) => throw StateError(failure.message),
    (account) => account,
  );
}

@Riverpod(keepAlive: true)
class BusinessAccountNotifier extends _$BusinessAccountNotifier {
  @override
  AsyncValue<void> build() {
    return const AsyncData(null);
  }

  Future<BusinessAccountActionResult> apply(
    BusinessAccountApplyParams params,
  ) async {
    state = const AsyncLoading<void>();
    final result = await ref.read(applyBusinessAccountUseCaseProvider).call(params);
    return result.fold(
      (failure) {
        state = AsyncError<void>(failure, StackTrace.current);
        return BusinessAccountActionResult(failure: failure);
      },
      (_) {
        state = const AsyncData<void>(null);
        ref.invalidate(myBusinessAccountProvider);
        return const BusinessAccountActionResult();
      },
    );
  }
}
