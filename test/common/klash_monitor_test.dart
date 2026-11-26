import 'dart:async';
import 'package:fl_clash/providers/ip_quality.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/common/klash_monitor.dart';
import 'package:fl_clash/common/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    loadAppLocalizations(const Locale('en'));
  });

  test(
    'quality refresh survives the tray temporarily releasing its listener',
    () async {
      var calls = 0;
      final answer = Completer<IpQuality>();
      const quality = IpQuality(
        ip: '2.2.2.2',
        source: IpQualitySource.identMe,
        type: IpType.residential,
      );
      final container = ProviderContainer(
        overrides: [
          ipQualityProvider('2.2.2.2').overrideWith((ref) async {
            calls++;
            return calls == 1 ? quality : answer.future;
          }),
        ],
      );
      addTearDown(container.dispose);
      final ui = container.listen(ipQualityProvider('2.2.2.2'), (_, _) {});
      await container.read(ipQualityProvider('2.2.2.2').future);
      final refresh = refreshKlashQuality(container.read, '2.2.2.2');
      ui.close();
      await Future<void>.delayed(Duration.zero);
      expect(calls, 2);
      answer.complete(quality);
      await refresh;
    },
  );

  test(
    'restores a previous Flash monitor preference without deleting it',
    () async {
      SharedPreferences.setMockInitialValues({'flash.monitorTarget': 'Auto'});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(klashMonitorTargetProvider);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(klashMonitorTargetProvider), 'Auto');
      await container.read(klashMonitorTargetProvider.notifier).select('Japan');
      final store = await SharedPreferences.getInstance();
      expect(store.getString('klash.monitorTarget'), 'Japan');
      expect(store.getString('flash.monitorTarget'), 'Auto');
    },
  );

  test(
    'missing target remains explicit instead of reverting to rules',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container
          .read(klashMonitorTargetProvider.notifier)
          .select('Removed');
      expect(container.read(klashMonitorTargetProvider), 'Removed');
    },
  );

  test(
    'selection survives restart and last selection wins persistence',
    () async {
      final first = ProviderContainer();
      await first.read(klashMonitorTargetProvider.notifier).select('Manual');
      await first.read(klashMonitorTargetProvider.notifier).select('Auto');
      expect(first.read(klashMonitorTargetProvider), 'Auto');
      first.dispose();
      final second = ProviderContainer();
      addTearDown(second.dispose);
      second.read(klashMonitorTargetProvider);
      await Future<void>.delayed(Duration.zero);
      expect(second.read(klashMonitorTargetProvider), 'Auto');
    },
  );
}
