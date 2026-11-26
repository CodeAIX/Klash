import 'dart:async';

import 'package:fl_clash/common/klash_monitor.dart';

import 'package:collection/collection.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/tray.dart';
import 'package:fl_clash/common/window.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/providers/outbound_ip.dart';
import 'package:fl_clash/providers/ip_quality.dart';
import 'package:fl_clash/providers/routed_probe.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/route_state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rust_api/tray.dart';

class TrayManager extends ConsumerStatefulWidget {
  final Widget child;

  const TrayManager({super.key, required this.child});

  @override
  ConsumerState<TrayManager> createState() => _TrayManagerState();
}

class _TrayManagerState extends ConsumerState<TrayManager> {
  StreamSubscription<TrayEvent>? _subscription;
  Timer? _klashTimer;
  ProviderSubscription<AsyncValue<IpQuality>>? _qualitySubscription;
  String? _qualityIp;
  bool _klashWatching = false;
  String? _klashTarget;
  OutboundIpProbe? _klashProbe;
  RouteTracker? _klashRoute;
  bool _isUpdating = false;
  bool _hasPendingUpdate = false;

  @override
  void initState() {
    super.initState();
    _subscription = Tray.instance.events.listen(_handleTrayEvent);
    ref.listenManual(trayStateProvider, (prev, next) {
      if (prev != next) {
        _requestUpdate();
      }
    });
    ref.listenManual(loadedLocaleProvider, (prev, next) {
      if (prev != null && prev != next) {
        _requestUpdate();
      }
    });
    if (system.isMacOS &&
        const bool.fromEnvironment('KLASH_STATUS_ICON', defaultValue: true)) {
      ref.listenManual(klashMonitorTargetProvider, (_, _) {
        scheduleMicrotask(_syncKlashWatch);
        _requestUpdate();
      });
      ref.listenManual(groupsProvider, (_, _) => _requestUpdate());
      scheduleMicrotask(_syncKlashWatch);
      ref.listenManual(
        trayStateProvider,
        (_, _) => scheduleMicrotask(_syncKlashWatch),
      );
      ref.listenManual(outboundIpProbeProvider, (_, _) {
        scheduleMicrotask(_syncKlashQuality);
        _requestUpdate();
      });
    }
    if (system.isMacOS) {
      ref.listenManual(trayDelaysProvider, (prev, next) {
        if (!const DeepCollectionEquality().equals(prev, next)) {
          _requestUpdate();
        }
      });
      ref.listenManual(trayTitleStateProvider, (prev, next) {
        if (prev != next) {
          _reportFailure(
            appTray?.updateTitle(
              showTrayTitle: next.showTrayTitle,
              traffic: next.traffic,
            ),
          );
        }
      });
    }
  }

  void _syncKlashWatch() {
    if (!mounted) return;
    final tray = ref.read(trayStateProvider);
    _syncKlashQuality();
    final wanted = !tray.safeMode && tray.isStart && !tray.suspended;
    final target = ref.read(klashMonitorTargetProvider);
    if (wanted == _klashWatching && target == _klashTarget) return;
    if (_klashWatching) {
      _klashTimer?.cancel();
      _klashProbe?.unwatch(_klashTarget!);
      _klashRoute?.detachBackground();
    }
    _klashWatching = wanted;
    _klashTarget = target;
    if (wanted) {
      _klashRoute = ref.read(routeTrackerProvider.notifier);
      _klashProbe = ref.read(outboundIpProbeProvider.notifier);
      _klashRoute!.attachBackground();
      _klashProbe!.watch(target);
      _klashProbe!.refresh([target]);
      _klashTimer = Timer.periodic(const Duration(seconds: 60), (_) {
        ref.read(outboundIpProbeProvider.notifier).refresh([target]);
      });
    } else {
      _klashTimer?.cancel();
      _klashProbe = null;
      _klashRoute = null;
    }
  }

  void _syncKlashQuality() {
    if (!mounted) return;
    final tray = ref.read(trayStateProvider);
    final entry = ref
        .read(outboundIpProbeProvider)
        .entryOf(ref.read(klashMonitorTargetProvider));
    final ip =
        !tray.safeMode &&
            tray.isStart &&
            !tray.suspended &&
            entry.phase == ProbePhase.fresh
        ? entry.value?.ip
        : null;
    if (ip == _qualityIp) return;
    _qualitySubscription?.close();
    _qualitySubscription = null;
    _qualityIp = ip;
    if (ip != null) {
      _qualitySubscription = ref.listenManual(
        ipQualityProvider(ip),
        (_, _) => _requestUpdate(),
      );
    }
  }

  /// A delay test changes the menu per proxy, so updates in flight coalesce.
  void _requestUpdate() {
    if (_isUpdating) {
      _hasPendingUpdate = true;
      return;
    }
    _isUpdating = true;
    _reportFailure(_drainUpdates());
  }

  Future<void> _drainUpdates() async {
    try {
      do {
        _hasPendingUpdate = false;
        await ref.read(systemActionProvider.notifier).updateTray();
      } while (_hasPendingUpdate && mounted);
    } finally {
      _isUpdating = false;
      if (_hasPendingUpdate && mounted) {
        _requestUpdate();
      }
    }
  }

  void _reportFailure(Future<void>? operation) {
    if (operation == null) {
      return;
    }
    unawaited(
      operation.onError<Object>((error, stackTrace) {
        commonPrint.log(
          'Tray operation failed: ${compactError(error)}',
          logLevel: LogLevel.error,
        );
      }),
    );
  }

  void _handleTrayEvent(TrayEvent event) {
    switch (event) {
      case TrayIconActivated():
        window?.show();
      case TrayMenuRequested():
        _reportFailure(Tray.instance.openMenu());
      case TrayMenuItemSelected():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void dispose() {
    _qualitySubscription?.close();
    _klashTimer?.cancel();
    if (_klashWatching) {
      _klashProbe?.unwatch(_klashTarget!);
      _klashRoute?.detachBackground();
      _klashProbe = null;
      _klashRoute = null;
    }
    _subscription?.cancel();
    super.dispose();
  }
}
