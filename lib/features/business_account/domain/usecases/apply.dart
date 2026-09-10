import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/business_account/domain/entities/business_account_entity.dart';
import 'package:bakaloo_flutter_app/features/business_account/domain/repositories/business_account_repository.dart';

class ApplyBusinessAccountUseCase {
  const ApplyBusinessAccountUseCase(this._repository);

  final BusinessAccountRepository _repository;

  Future<Either<Failure, BusinessAccountEntity>> call(
    BusinessAccountApplyParams params,
  ) {
    return _repository.apply(params);
  }
}
