import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/ledger/domain/entities/ledger_account_entity.dart';

abstract class LedgerRepository {
  /// The caller's own ledger account, or null if they don't have one.
  Future<Either<Failure, LedgerAccountEntity?>> getMine();

  /// Settles an already-placed (PENDING) order from the B2B credit line.
  Future<Either<Failure, void>> payFromLedger(String orderId);
}
