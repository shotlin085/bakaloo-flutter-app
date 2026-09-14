import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/spin_wheel/domain/entities/spin_appearance.dart';
import 'package:bakaloo_flutter_app/features/spin_wheel/domain/repositories/spin_wheel_repository.dart';

class GetSpinAppearanceUseCase {
  const GetSpinAppearanceUseCase(this._repository);

  final SpinWheelRepository _repository;

  Future<Either<Failure, SpinAppearance>> call() {
    return _repository.getAppearance();
  }
}
