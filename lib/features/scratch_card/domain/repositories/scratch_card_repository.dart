import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/scratch_card/domain/entities/scratch_appearance.dart';
import 'package:bakaloo_flutter_app/features/scratch_card/domain/entities/scratch_eligibility.dart';
import 'package:bakaloo_flutter_app/features/scratch_card/domain/entities/scratch_result.dart';

abstract class ScratchCardRepository {
  Future<Either<Failure, ScratchAppearance>> getAppearance();
  Future<Either<Failure, ScratchEligibility>> getEligibility();
  Future<Either<Failure, ScratchResult>> scratch();
}
