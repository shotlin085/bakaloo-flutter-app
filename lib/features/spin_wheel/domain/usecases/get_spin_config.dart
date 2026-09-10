import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/spin_wheel/domain/entities/spin_prize.dart';
import 'package:bakaloo_flutter_app/features/spin_wheel/domain/repositories/spin_wheel_repository.dart';

class GetSpinConfigUseCase {
  const GetSpinConfigUseCase(this._repository);

  final SpinWheelRepository _repository;

  Future<Either<Failure, List<SpinPrize>>> call() {
    return _repository.getConfig();
  }
}
