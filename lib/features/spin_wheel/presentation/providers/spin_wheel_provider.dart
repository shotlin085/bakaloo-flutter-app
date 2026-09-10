import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/di/providers.dart';
import 'package:bakaloo_flutter_app/features/spin_wheel/data/datasources/spin_wheel_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/spin_wheel/data/repositories/spin_wheel_repository_impl.dart';
import 'package:bakaloo_flutter_app/features/spin_wheel/domain/entities/spin_eligibility.dart';
import 'package:bakaloo_flutter_app/features/spin_wheel/domain/entities/spin_prize.dart';
import 'package:bakaloo_flutter_app/features/spin_wheel/domain/entities/spin_result.dart';
import 'package:bakaloo_flutter_app/features/spin_wheel/domain/repositories/spin_wheel_repository.dart';
import 'package:bakaloo_flutter_app/features/spin_wheel/domain/usecases/get_spin_config.dart';
import 'package:bakaloo_flutter_app/features/spin_wheel/domain/usecases/get_spin_eligibility.dart';
import 'package:bakaloo_flutter_app/features/spin_wheel/domain/usecases/spin.dart';

part 'spin_wheel_provider.g.dart';

final spinWheelRemoteDataSourceProvider = Provider<SpinWheelRemoteDataSource>((
  Ref ref,
) {
  return SpinWheelRemoteDataSource(ref.watch(apiClientProvider));
});

final spinWheelRepositoryProvider = Provider<SpinWheelRepository>((Ref ref) {
  return SpinWheelRepositoryImpl(
    remoteDataSource: ref.watch(spinWheelRemoteDataSourceProvider),
  );
});

final getSpinConfigUseCaseProvider = Provider<GetSpinConfigUseCase>((Ref ref) {
  return GetSpinConfigUseCase(ref.watch(spinWheelRepositoryProvider));
});

final getSpinEligibilityUseCaseProvider = Provider<GetSpinEligibilityUseCase>((
  Ref ref,
) {
  return GetSpinEligibilityUseCase(ref.watch(spinWheelRepositoryProvider));
});

final spinUseCaseProvider = Provider<SpinUseCase>((Ref ref) {
  return SpinUseCase(ref.watch(spinWheelRepositoryProvider));
});

/// The active wheel — active prizes fetched from `GET /spin-wheel/config`,
/// 2-8 entries, admin-configured. Falls back to [kSpinWheelPrizes] on any
/// failure so the dialog still renders a wheel instead of a blank/broken
/// state; [SpinWinDialog] disables the SPIN action while showing that
/// fallback (see its own doc comment — a fallback id never matches a real
/// backend spin result).
@riverpod
Future<List<SpinPrize>> spinConfig(Ref ref) async {
  final either = await ref.watch(getSpinConfigUseCaseProvider).call();
  return either.fold(
    (failure) => kSpinWheelPrizes,
    (prizes) => prizes.isEmpty ? kSpinWheelPrizes : prizes,
  );
}

/// Whether the fetched wheel is real (backend-configured) vs. the offline
/// fallback — [SpinWinDialog] uses this to decide whether SPIN is allowed.
@riverpod
Future<bool> spinConfigIsLive(Ref ref) async {
  final either = await ref.watch(getSpinConfigUseCaseProvider).call();
  return either.fold((failure) => false, (prizes) => prizes.isNotEmpty);
}

/// How many spins the user has right now, and where the popup should
/// auto-trigger. Deliberately a plain [FutureProvider] (not keepAlive) —
/// re-fetched fresh every time something reads it (see
/// `spin_win_dialog.dart`'s `ref.invalidate` after each spin, and
/// `home_screen.dart`'s one-shot read on the onboarding chain).
@riverpod
Future<SpinEligibility> spinEligibility(Ref ref) async {
  final either = await ref.watch(getSpinEligibilityUseCaseProvider).call();
  return either.fold(
    (failure) => throw StateError(failure.message),
    (value) => value,
  );
}

enum SpinWheelStatus { idle, spinning, result }

class SpinWheelState {
  const SpinWheelState({this.status = SpinWheelStatus.idle, this.resolved});

  final SpinWheelStatus status;
  final ResolvedSpin? resolved;
}

/// Drives *what* is won (the network call + which wedge index to land the
/// animation on); [SpinWheelDial] separately drives *how the wheel gets
/// there* (the rotation animation itself, unchanged since phase 1).
///
/// The index lookup matches [SpinResult.prizeId] against the prize list the
/// CALLER is currently rendering (passed in explicitly, not read from
/// [spinConfigProvider] internally) — `spin_win_dialog.dart` always passes
/// the exact same list it built the wheel from, so the animation lands on
/// the wedge the customer is actually looking at, never a value this
/// notifier fetched independently and might disagree with.
class SpinWheelNotifier extends Notifier<SpinWheelState> {
  @override
  SpinWheelState build() => const SpinWheelState();

  Future<SpinResult?> spin(List<SpinPrize> currentPrizes) async {
    state = const SpinWheelState(status: SpinWheelStatus.spinning);
    final either = await ref.read(spinUseCaseProvider).call();
    return either.fold(
      (failure) {
        state = const SpinWheelState();
        return null;
      },
      (result) {
        if (!result.success) {
          state = const SpinWheelState();
          return result;
        }
        final index = currentPrizes.indexWhere((p) => p.id == result.prizeId);
        state = SpinWheelState(
          status: SpinWheelStatus.result,
          resolved: ResolvedSpin(prizeIndex: index == -1 ? 0 : index, result: result),
        );
        return result;
      },
    );
  }

  void reset() {
    state = const SpinWheelState();
  }
}

final spinWheelProvider = NotifierProvider<SpinWheelNotifier, SpinWheelState>(
  SpinWheelNotifier.new,
);
