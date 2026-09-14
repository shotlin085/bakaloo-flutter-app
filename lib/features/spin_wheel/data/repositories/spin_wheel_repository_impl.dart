import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/errors/error_handler.dart';
import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/spin_wheel/data/datasources/spin_wheel_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/spin_wheel/domain/entities/spin_appearance.dart';
import 'package:bakaloo_flutter_app/features/spin_wheel/domain/entities/spin_eligibility.dart';
import 'package:bakaloo_flutter_app/features/spin_wheel/domain/entities/spin_prize.dart';
import 'package:bakaloo_flutter_app/features/spin_wheel/domain/entities/spin_result.dart';
import 'package:bakaloo_flutter_app/features/spin_wheel/domain/repositories/spin_wheel_repository.dart';

class SpinWheelRepositoryImpl implements SpinWheelRepository {
  const SpinWheelRepositoryImpl({
    required SpinWheelRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final SpinWheelRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, List<SpinPrize>>> getConfig() async {
    try {
      final models = await _remoteDataSource.getConfig();
      final sorted = [...models]..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      return Right(
        <SpinPrize>[
          for (var i = 0; i < sorted.length; i++) sorted[i].toEntity(i),
        ],
      );
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to load the spin wheel right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, SpinAppearance>> getAppearance() async {
    try {
      final appearance = await _remoteDataSource.getAppearance();
      return Right(appearance);
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to load spin wheel appearance right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, SpinEligibility>> getEligibility() async {
    try {
      final eligibility = await _remoteDataSource.getEligibility();
      return Right(eligibility);
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to check your spins right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, SpinResult>> spin() async {
    try {
      final result = await _remoteDataSource.spin();
      return Right(result);
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to spin right now — please try again.'),
      );
    }
  }
}
