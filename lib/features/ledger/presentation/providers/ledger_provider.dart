import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/di/providers.dart';
import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/ledger/data/datasources/ledger_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/ledger/data/repositories/ledger_repository_impl.dart';
import 'package:bakaloo_flutter_app/features/ledger/domain/entities/ledger_account_entity.dart';
import 'package:bakaloo_flutter_app/features/ledger/domain/repositories/ledger_repository.dart';
import 'package:bakaloo_flutter_app/features/ledger/domain/usecases/get_mine.dart';
import 'package:bakaloo_flutter_app/features/ledger/domain/usecases/pay_from_ledger.dart';

part 'ledger_provider.g.dart';

class LedgerActionResult {
  const LedgerActionResult({this.failure});

  final Failure? failure;

  bool get isSuccess => failure == null;
}

final ledgerRemoteDataSourceProvider = Provider<LedgerRemoteDataSource>((Ref ref) {
  return LedgerRemoteDataSource(ref.watch(apiClientProvider));
});

final ledgerRepositoryProvider = Provider<LedgerRepository>((Ref ref) {
  return LedgerRepositoryImpl(
    remoteDataSource: ref.watch(ledgerRemoteDataSourceProvider),
  );
});

final getMyLedgerAccountUseCaseProvider = Provider<GetMyLedgerAccountUseCase>((Ref ref) {
  return GetMyLedgerAccountUseCase(ref.watch(ledgerRepositoryProvider));
});

final payFromLedgerUseCaseProvider = Provider<PayFromLedgerUseCase>((Ref ref) {
  return PayFromLedgerUseCase(ref.watch(ledgerRepositoryProvider));
});

/// The caller's own ledger (B2B credit) account — null when none has been
/// set up for them by an admin yet. Drives whether "Pay via Ledger" is
/// offered at checkout.
@riverpod
Future<LedgerAccountEntity?> myLedgerAccount(Ref ref) async {
  final result = await ref.read(getMyLedgerAccountUseCaseProvider).call();
  return result.fold(
    (failure) => throw StateError(failure.message),
    (account) => account,
  );
}

@Riverpod(keepAlive: true)
class LedgerNotifier extends _$LedgerNotifier {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// Settles an already-placed order from the B2B credit line.
  Future<LedgerActionResult> payFromLedger(String orderId) async {
    state = const AsyncLoading<void>();
    final result = await ref.read(payFromLedgerUseCaseProvider).call(orderId);
    return result.fold(
      (failure) {
        state = AsyncError<void>(failure, StackTrace.current);
        return LedgerActionResult(failure: failure);
      },
      (_) {
        state = const AsyncData<void>(null);
        ref.invalidate(myLedgerAccountProvider);
        return const LedgerActionResult();
      },
    );
  }
}
