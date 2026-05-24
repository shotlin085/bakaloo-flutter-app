import 'package:freezed_annotation/freezed_annotation.dart';

part 'category_entity.freezed.dart';

@freezed
abstract class CategoryEntity with _$CategoryEntity {
  const CategoryEntity._();

  const factory CategoryEntity({
    required String id,
    required String name,
    required int sortOrder,
    required bool isActive,
    required int productCount,
    String? description,
    String? imageUrl,
    String? parentId,
  }) = _CategoryEntity;

  bool get isParent => parentId == null || parentId!.isEmpty;
}
