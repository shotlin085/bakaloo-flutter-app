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
      state = AppAvailabilityStatus.offline;
      return;
    }

    state = _serviceUnavailable
        ? AppAvailabilityStatus.serviceUnavailable
        : AppAvailabilityStatus.online;
  }

  void reportOffline() {
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

  void retry() {
    if (state != AppAvailabilityStatus.offline) {
      reportHealthy();
    }
  }
}

final appAvailabilityProvider =
    NotifierProvider<AppAvailabilityNotifier, AppAvailabilityStatus>(
  AppAvailabilityNotifier.new,
);
