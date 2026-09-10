import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/errors/error_handler.dart';
import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/business_account/data/datasources/business_account_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/business_account/domain/entities/business_account_entity.dart';
import 'package:bakaloo_flutter_app/features/business_account/domain/repositories/business_account_repository.dart';

class BusinessAccountRepositoryImpl implements BusinessAccountRepository {
  const BusinessAccountRepositoryImpl({
    required BusinessAccountRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final BusinessAccountRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, BusinessAccountEntity?>> getMine() async {
    try {
      final account = await _remoteDataSource.getMine();
      return Right(account);
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to load your business account right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, BusinessAccountEntity>> apply(
    BusinessAccountApplyParams params,
  ) async {
    try {
      final account = await _remoteDataSource.apply(params.toJson());
      return Right(account);
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to submit your application right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, BusinessAccountEntity>> toggle(bool enabled) async {
    try {
      final account = await _remoteDataSource.toggle(enabled);
      return Right(account);
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to update B2B pricing right now.'),
      );
    }
  }
}
