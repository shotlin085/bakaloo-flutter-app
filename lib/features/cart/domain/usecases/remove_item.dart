import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/cart_entity.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/repositories/cart_repository.dart';

class RemoveItemUseCase {
  const RemoveItemUseCase(this._repository);

  final CartRepository _repository;

  Future<Either<Failure, CartEntity>> call(String productId) {
    return _repository.removeItem(productId);
  }
}
