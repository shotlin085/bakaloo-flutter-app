import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bakaloo_flutter_app/core/network/network_monitor.dart';
import 'package:bakaloo_flutter_app/shared/providers/connectivity_provider.dart';

enum AppAvailabilityStatus {
  online,
  offline,
  serviceUnavailable,
}

class AppAvailabilityNotifier extends Notifier<AppAvailabilityStatus> {
  bool _serviceUnavailable = false;
  bool _browsingWhileOffline = false;

  @override
  AppAvailabilityStatus build() {
    final initialStatus = ref.watch(connectivityStatusProvider);

    ref.listen<AsyncValue<ConnectivityStatus>>(connectivityStatusProvider, (
      _,
      next,
    ) {
      next.whenData(syncConnectivity);
    });

    return initialStatus.maybeWhen(
      data: (ConnectivityStatus value) => value == ConnectivityStatus.offline
          ? AppAvailabilityStatus.offline
          : AppAvailabilityStatus.online,
      orElse: () => AppAvailabilityStatus.online,
    );
  }

  void syncConnectivity(ConnectivityStatus status) {
    if (status == ConnectivityStatus.offline) {
      // Respect a user who chose "Browse saved items" — don't re-block them.
      if (_browsingWhileOffline) {
        return;
      }
      state = AppAvailabilityStatus.offline;
      return;
    }

    // Genuine connectivity restored — clear the manual browse override.
    _browsingWhileOffline = false;
    state = _serviceUnavailable
        ? AppAvailabilityStatus.serviceUnavailable
        : AppAvailabilityStatus.online;
  }

  void reportOffline() {
    if (_browsingWhileOffline) {
      return;
    }
    state = AppAvailabilityStatus.offline;
  }

  void reportServiceUnavailable() {
    _serviceUnavailable = true;
    if (state != AppAvailabilityStatus.offline) {
      state = AppAvailabilityStatus.serviceUnavailable;
    }
  }

  void reportHealthy() {
    _serviceUnavailable = false;
    if (state != AppAvailabilityStatus.offline) {
      state = AppAvailabilityStatus.online;
    }
  }

  /// Re-checks live connectivity and clears the blocker when reachable.
  /// Used by the offline screen's "Retry" button.
  Future<void> retry() async {
    _browsingWhileOffline = false;

    final connected = await ref.read(networkMonitorProvider).isConnected;
    if (!connected) {
      state = AppAvailabilityStatus.offline;
      return;
    }

    _serviceUnavailable = false;
    state = AppAvailabilityStatus.online;
  }

  /// Dismisses the offline blocker so the user can browse cached/saved
  /// content. The blocker re-appears on the next failed request unless
  /// connectivity is genuinely restored.
  void browseOffline() {
    _browsingWhileOffline = true;
    state = AppAvailabilityStatus.online;
  }
}

final appAvailabilityProvider =
    NotifierProvider<AppAvailabilityNotifier, AppAvailabilityStatus>(
  AppAvailabilityNotifier.new,
);
