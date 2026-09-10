import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/business_account/domain/entities/business_account_entity.dart';

class BusinessAccountApplyParams {
  const BusinessAccountApplyParams({
    required this.companyName,
    required this.gstNumber,
  });

  final String companyName;
  final String gstNumber;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'companyName': companyName,
      'gstNumber': gstNumber,
    };
  }
}

abstract class BusinessAccountRepository {
  /// The caller's own business account, or null if they've never applied.
  Future<Either<Failure, BusinessAccountEntity?>> getMine();

  Future<Either<Failure, BusinessAccountEntity>> apply(
    BusinessAccountApplyParams params,
  );

  /// Only allowed once the account is APPROVED. Returns the updated account.
  Future<Either<Failure, BusinessAccountEntity>> toggle(bool enabled);
}
