import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/scratch_card/domain/entities/scratch_result.dart';
import 'package:bakaloo_flutter_app/features/scratch_card/domain/repositories/scratch_card_repository.dart';

class ScratchUseCase {
  const ScratchUseCase(this._repository);

  final ScratchCardRepository _repository;

  Future<Either<Failure, ScratchResult>> call() {
    return _repository.scratch();
  }
}
