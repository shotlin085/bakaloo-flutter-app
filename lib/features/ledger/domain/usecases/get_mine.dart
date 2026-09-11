import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/ledger/domain/entities/ledger_account_entity.dart';
import 'package:bakaloo_flutter_app/features/ledger/domain/repositories/ledger_repository.dart';

class GetMyLedgerAccountUseCase {
  const GetMyLedgerAccountUseCase(this._repository);

  final LedgerRepository _repository;

  Future<Either<Failure, LedgerAccountEntity?>> call() {
    return _repository.getMine();
  }
}
