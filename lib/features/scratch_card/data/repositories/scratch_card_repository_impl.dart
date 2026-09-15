import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/errors/error_handler.dart';
import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/scratch_card/data/datasources/scratch_card_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/scratch_card/domain/entities/scratch_appearance.dart';
import 'package:bakaloo_flutter_app/features/scratch_card/domain/entities/scratch_eligibility.dart';
import 'package:bakaloo_flutter_app/features/scratch_card/domain/entities/scratch_result.dart';
import 'package:bakaloo_flutter_app/features/scratch_card/domain/repositories/scratch_card_repository.dart';

class ScratchCardRepositoryImpl implements ScratchCardRepository {
  const ScratchCardRepositoryImpl({
    required ScratchCardRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final ScratchCardRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, ScratchAppearance>> getAppearance() async {
    try {
      final appearance = await _remoteDataSource.getAppearance();
      return Right(appearance);
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to load scratch card appearance right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, ScratchEligibility>> getEligibility() async {
    try {
      final eligibility = await _remoteDataSource.getEligibility();
      return Right(eligibility);
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to check your scratch cards right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, ScratchResult>> scratch() async {
    try {
      final result = await _remoteDataSource.scratch();
      return Right(result);
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to scratch right now — please try again.'),
      );
    }
  }
}
