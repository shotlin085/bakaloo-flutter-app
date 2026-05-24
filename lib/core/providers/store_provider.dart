import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bakaloo_flutter_app/core/models/store_model.dart';

class _SelectedStoreNotifier extends Notifier<StoreModel> {
  @override
  StoreModel build() => appStores.first;

  void select(StoreModel store) => state = store;
}

class _SelectedCategoryNotifier extends Notifier<String> {
  @override
  String build() => 'all';

  void select(String id) => state = id;
}

final selectedStoreProvider =
    NotifierProvider<_SelectedStoreNotifier, StoreModel>(
  _SelectedStoreNotifier.new,
);

final selectedCategoryIdProvider =
    NotifierProvider<_SelectedCategoryNotifier, String>(
  _SelectedCategoryNotifier.new,
);
