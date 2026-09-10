import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/spin_wheel/domain/entities/spin_eligibility.dart';
import 'package:bakaloo_flutter_app/features/spin_wheel/domain/repositories/spin_wheel_repository.dart';

class GetSpinEligibilityUseCase {
  const GetSpinEligibilityUseCase(this._repository);

  final SpinWheelRepository _repository;

  Future<Either<Failure, SpinEligibility>> call() {
    return _repository.getEligibility();
  }
}
