import 'dart:async';

import 'package:fl_clash/common/provider_reader.dart';
import 'package:fl_clash/providers/ip_quality.dart';

import 'package:fl_clash/common/service_probe.dart';
import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final klashMonitorTargetProvider = NotifierProvider<KlashMonitorTarget, String>(
  KlashMonitorTarget.new,
);

class KlashMonitorTarget extends Notifier<String> {
  static const preferenceKey = 'klash.monitorTarget';
  int _revision = 0;
  Future<void> _writes = Future.value();

  @override
  String build() {
    unawaited(_restore());
    return routedOutbound;
  }

  Future<void> _restore() async {
    try {
      final store = await SharedPreferences.getInstance();
      if (ref.mounted && _revision == 0) {
        state =
            store.getString(preferenceKey) ??
            store.getString('flash.monitorTarget') ??
            routedOutbound;
      }
    } catch (_) {
      // A missing preference store must not prevent tray startup.
    }
  }

  Future<void> select(String target) {
    _revision++;
    state = target;
    return _writes = _writes
        .then((_) async {
          final store = await SharedPreferences.getInstance();
          await store.setString(preferenceKey, target);
        })
        .catchError((Object error) {});
  }
}

final _qualityRefreshProvider = Provider<Future<void> Function(String)>(
  (ref) => (ip) async {
    final hold = ref.listen(ipQualityProvider(ip), (_, _) {});
    try {
      ref.invalidate(ipQualityProvider(ip));
      await ref.read(ipQualityProvider(ip).future);
    } finally {
      hold.close();
    }
  },
);
Future<void> refreshKlashQuality(ProviderReader read, String ip) =>
    read(_qualityRefreshProvider)(ip);
