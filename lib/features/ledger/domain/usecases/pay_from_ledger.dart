import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/ledger/domain/repositories/ledger_repository.dart';

class PayFromLedgerUseCase {
  const PayFromLedgerUseCase(this._repository);

  final LedgerRepository _repository;

  Future<Either<Failure, void>> call(String orderId) {
    return _repository.payFromLedger(orderId);
  }
}
