import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/scratch_card/domain/entities/scratch_eligibility.dart';
import 'package:bakaloo_flutter_app/features/scratch_card/domain/repositories/scratch_card_repository.dart';

class GetScratchEligibilityUseCase {
  const GetScratchEligibilityUseCase(this._repository);

  final ScratchCardRepository _repository;

  Future<Either<Failure, ScratchEligibility>> call() {
    return _repository.getEligibility();
  }
}
