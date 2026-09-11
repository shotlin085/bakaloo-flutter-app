import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/errors/error_handler.dart';
import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/ledger/data/datasources/ledger_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/ledger/domain/entities/ledger_account_entity.dart';
import 'package:bakaloo_flutter_app/features/ledger/domain/repositories/ledger_repository.dart';

class LedgerRepositoryImpl implements LedgerRepository {
  const LedgerRepositoryImpl({
    required LedgerRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final LedgerRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, LedgerAccountEntity?>> getMine() async {
    try {
      final account = await _remoteDataSource.getMine();
      return Right(account);
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to load your ledger account right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> payFromLedger(String orderId) async {
    try {
      await _remoteDataSource.payFromLedger(orderId);
      return const Right(null);
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to pay from your ledger account right now.'),
      );
    }
  }
}
