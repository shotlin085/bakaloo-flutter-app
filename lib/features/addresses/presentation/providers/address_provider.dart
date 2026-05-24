import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/di/providers.dart';
import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/addresses/data/datasources/address_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/addresses/data/repositories/address_repository_impl.dart';
import 'package:bakaloo_flutter_app/features/addresses/domain/entities/address_entity.dart';
import 'package:bakaloo_flutter_app/features/addresses/domain/repositories/address_repository.dart';
import 'package:bakaloo_flutter_app/features/addresses/domain/usecases/create_address_usecase.dart';
import 'package:bakaloo_flutter_app/features/addresses/domain/usecases/delete_address_usecase.dart';
import 'package:bakaloo_flutter_app/features/addresses/domain/usecases/get_addresses_usecase.dart';
import 'package:bakaloo_flutter_app/features/addresses/domain/usecases/set_default_address_usecase.dart';
import 'package:bakaloo_flutter_app/features/addresses/domain/usecases/update_address_usecase.dart';
import 'package:bakaloo_flutter_app/features/addresses/domain/usecases/validate_pincode_usecase.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_state.dart';
import 'package:bakaloo_flutter_app/shared/widgets/confirmation_dialog.dart';

part 'address_provider.g.dart';

final addressRemoteDataSourceProvider = Provider<AddressRemoteDataSource>((
  Ref ref,
) {
  return AddressRemoteDataSource(ref.watch(apiClientProvider));
});

final addressRepositoryProvider = Provider<AddressRepository>((Ref ref) {
  final authState = ref.watch(authStateProvider);
  final fallbackName = switch (authState) {
    AuthAuthenticated(:final user)
        when user.name != null && user.name!.trim().isNotEmpty =>
      user.name!.trim(),
    _ => 'Bakaloo Customer',
  };
  final fallbackPhone = switch (authState) {
    AuthAuthenticated(:final user) => user.phone,
    _ => '',
  };

  return AddressRepositoryImpl(
    remoteDataSource: ref.watch(addressRemoteDataSourceProvider),
    fallbackName: fallbackName,
    fallbackPhone: fallbackPhone,
  );
});

final getAddressesUseCaseProvider = Provider<GetAddressesUseCase>((Ref ref) {
  return GetAddressesUseCase(ref.watch(addressRepositoryProvider));
});

final createAddressUseCaseProvider = Provider<CreateAddressUseCase>((Ref ref) {
  return CreateAddressUseCase(ref.watch(addressRepositoryProvider));
});

final updateAddressUseCaseProvider = Provider<UpdateAddressUseCase>((Ref ref) {
  return UpdateAddressUseCase(ref.watch(addressRepositoryProvider));
});

final deleteAddressUseCaseProvider = Provider<DeleteAddressUseCase>((Ref ref) {
  return DeleteAddressUseCase(ref.watch(addressRepositoryProvider));
});

final setDefaultAddressUseCaseProvider =
    Provider<SetDefaultAddressUseCase>((Ref ref) {
  return SetDefaultAddressUseCase(ref.watch(addressRepositoryProvider));
});

final validatePincodeUseCaseProvider =
    Provider<ValidatePincodeUseCase>((Ref ref) {
  return ValidatePincodeUseCase(ref.watch(addressRepositoryProvider));
});

class AddressActionResult {
  const AddressActionResult({
    this.failure,
    this.cancelled = false,
  });

  final Failure? failure;
  final bool cancelled;

  bool get isSuccess => failure == null && !cancelled;
}

@riverpod
class AddressNotifier extends _$AddressNotifier {
  @override
  Future<List<AddressEntity>> build() async {
    final result = await ref.read(getAddressesUseCaseProvider).call();
    return result.fold(
      (failure) => throw StateError(failure.message),
      _sortAddresses,
    );
  }

  Future<AddressActionResult> createAddress(AddressUpsertParams params) async {
    final result = await ref.read(createAddressUseCaseProvider).call(params);

    return result.fold(
      (failure) => AddressActionResult(failure: failure),
      (address) {
        final next = _sortAddresses(<AddressEntity>[
          ..._currentAddresses.where((item) => item.id != address.id),
          address,
        ]);
        state = AsyncData(next);
        ref.invalidateSelf();
        return const AddressActionResult();
      },
    );
  }

  Future<AddressActionResult> updateAddress(
    String id,
    AddressUpsertParams params,
  ) async {
    final result =
        await ref.read(updateAddressUseCaseProvider).call(id, params);

    return result.fold(
      (failure) => AddressActionResult(failure: failure),
      (address) {
        final next = _sortAddresses(
          _currentAddresses
              .map((item) => item.id == id ? address : item)
              .toList(growable: false),
        );
        state = AsyncData(next);
        return const AddressActionResult();
      },
    );
  }

  Future<AddressActionResult> deleteAddress(
    BuildContext context,
    String id,
  ) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Delete address?',
      message: 'This saved address will be removed from your account.',
      confirmLabel: 'Delete',
    );

    if (confirmed != true) {
      return const AddressActionResult(cancelled: true);
    }

    final result = await ref.read(deleteAddressUseCaseProvider).call(id);

    return result.fold(
      (failure) => AddressActionResult(failure: failure),
      (_) {
        final next = _currentAddresses
            .where((item) => item.id != id)
            .toList(growable: false);
        state = AsyncData(_sortAddresses(next));
        return const AddressActionResult();
      },
    );
  }

  Future<AddressActionResult> setDefault(String id) async {
    final previous = _currentAddresses;
    final optimistic = _sortAddresses(
      previous
          .map(
            (item) => item.copyWith(
              isDefault: item.id == id,
            ),
          )
          .toList(growable: false),
    );
    state = AsyncData(optimistic);

    final result = await ref.read(setDefaultAddressUseCaseProvider).call(id);

    return result.fold(
      (failure) {
        state = AsyncData(previous);
        return AddressActionResult(failure: failure);
      },
      (address) {
        final next = _sortAddresses(
          previous
              .map(
                (item) => item.id == id
                    ? address.copyWith(isDefault: true)
                    : item.copyWith(isDefault: false),
              )
              .toList(growable: false),
        );
        state = AsyncData(next);
        return const AddressActionResult();
      },
    );
  }

  void refresh() {
    ref.invalidateSelf();
  }

  List<AddressEntity> get _currentAddresses => switch (state) {
        AsyncData(:final value) => value,
        _ => const <AddressEntity>[],
      };

  List<AddressEntity> _sortAddresses(List<AddressEntity> addresses) {
    return addresses.toList(growable: true)
      ..sort((a, b) {
        if (a.isDefault == b.isDefault) {
          return a.label.compareTo(b.label);
        }
        return a.isDefault ? -1 : 1;
      });
  }
}
