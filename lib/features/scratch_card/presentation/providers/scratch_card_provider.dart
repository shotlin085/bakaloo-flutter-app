import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/di/providers.dart';
import 'package:bakaloo_flutter_app/features/scratch_card/data/datasources/scratch_card_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/scratch_card/data/repositories/scratch_card_repository_impl.dart';
import 'package:bakaloo_flutter_app/features/scratch_card/domain/entities/scratch_appearance.dart';
import 'package:bakaloo_flutter_app/features/scratch_card/domain/entities/scratch_eligibility.dart';
import 'package:bakaloo_flutter_app/features/scratch_card/domain/repositories/scratch_card_repository.dart';
import 'package:bakaloo_flutter_app/features/scratch_card/domain/usecases/get_scratch_appearance.dart';
import 'package:bakaloo_flutter_app/features/scratch_card/domain/usecases/get_scratch_eligibility.dart';
import 'package:bakaloo_flutter_app/features/scratch_card/domain/usecases/scratch.dart';

part 'scratch_card_provider.g.dart';

final scratchCardRemoteDataSourceProvider = Provider<ScratchCardRemoteDataSource>((
  Ref ref,
) {
  return ScratchCardRemoteDataSource(ref.watch(apiClientProvider));
});

final scratchCardRepositoryProvider = Provider<ScratchCardRepository>((Ref ref) {
  return ScratchCardRepositoryImpl(
    remoteDataSource: ref.watch(scratchCardRemoteDataSourceProvider),
  );
});

final getScratchAppearanceUseCaseProvider = Provider<GetScratchAppearanceUseCase>((
  Ref ref,
) {
  return GetScratchAppearanceUseCase(ref.watch(scratchCardRepositoryProvider));
});

final getScratchEligibilityUseCaseProvider = Provider<GetScratchEligibilityUseCase>((
  Ref ref,
) {
  return GetScratchEligibilityUseCase(ref.watch(scratchCardRepositoryProvider));
});

/// No wrapping Notifier/state-machine here (unlike spin-wheel's
/// SpinWheelNotifier) — that one exists purely to carry a resolved wedge
/// *index* for the wheel-landing animation, which a scratch card has no
/// equivalent of. Read directly: `ref.read(scratchUseCaseProvider).call()`.
final scratchUseCaseProvider = Provider<ScratchUseCase>((Ref ref) {
  return ScratchUseCase(ref.watch(scratchCardRepositoryProvider));
});

/// Cover ("foil") image, dashboard-configured. Falls back to an all-null
/// [ScratchAppearance] on any failure — `scratch_card_dialog.dart` reads a
/// null cover as "use a plain branded color instead of an image", same
/// fail-open philosophy as spin-wheel's appearance provider.
///
/// `keepAlive: true` deliberately, unlike most providers in this feature —
/// this rarely changes, and the popup can open/close many times in one
/// session (auto-prompt, then Profile tile, then again...). Without it,
/// autoDispose tears this down moments after each close, so the NEXT open
/// briefly shows the default foil again while it re-fetches — a visible
/// "wrong cover flashes before the real one" flicker on every open after
/// the first. Caching for the session's lifetime means only the very
/// first open ever pays that fetch.
@Riverpod(keepAlive: true)
Future<ScratchAppearance> scratchCardAppearance(Ref ref) async {
  final either = await ref.watch(getScratchAppearanceUseCaseProvider).call();
  return either.fold((failure) => const ScratchAppearance(), (value) => value);
}

/// How many scratch cards the user has right now, and where the popup
/// should auto-trigger. Deliberately a plain [FutureProvider] (not
/// keepAlive), same reasoning as spinEligibilityProvider — re-fetched fresh
/// every time something reads it.
@riverpod
Future<ScratchEligibility> scratchEligibility(Ref ref) async {
  final either = await ref.watch(getScratchEligibilityUseCaseProvider).call();
  return either.fold(
    (failure) => throw StateError(failure.message),
    (value) => value,
  );
}
