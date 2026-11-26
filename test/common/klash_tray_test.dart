import 'dart:io';

import 'package:fl_clash/common/app_localizations.dart';
import 'package:fl_clash/common/klash_monitor.dart';
import 'package:fl_clash/common/tray.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/ip_quality.dart';
import 'package:fl_clash/providers/outbound_ip.dart';
import 'package:fl_clash/providers/routed_probe.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:rust_api/tray.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/app_paths.dart';
import '../helpers/fake_tray_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late ProviderContainer container;
  late FakeTrayHost host;

  setUpAll(() async {
    directory = Directory.systemTemp.createTempSync('klash_tray_');
    await useAppPaths(directory);
    loadAppLocalizations(const Locale('en'));
  });
  tearDownAll(() => directory.deleteSync(recursive: true));
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    SharedPreferences.setMockInitialValues({});
    host = FakeTrayHost();
    Tray.instance.resetForTesting(host);
    container = ProviderContainer();
  });
  tearDown(() {
    container.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  Future<void> show({
    bool running = true,
    bool tun = false,
    bool proxy = true,
    bool safe = false,
    List<Group> groups = const [],
  }) => AppTray.forPlatform(isMacOS: true, isWindows: false).update(
    trayState: TrayState(
      mode: Mode.rule,
      port: 7890,
      autoLaunch: false,
      systemProxy: proxy,
      tunEnable: tun,
      isStart: running,
      groups: groups,
      selectedMap: const {},
      showTrayTitle: false,
      safeMode: safe,
    ),
    traffic: const Traffic(),
    read: container.read,
  );

  void answers(ProbePhase phase, {bool good = false}) {
    container.dispose();
    container = ProviderContainer(
      overrides: [
        outboundIpProbeProvider.overrideWithBuild(
          (_, _) => RoutedProbeState({
            '': ProbeEntry(
              phase: phase,
              value: const IpInfo(ip: '1.1.1.1', countryCode: 'US'),
            ),
            'Manual': ProbeEntry(
              phase: phase,
              value: const IpInfo(ip: '2.2.2.2', countryCode: 'JP'),
            ),
          }),
        ),
        ipQualityProvider('2.2.2.2').overrideWithValue(
          AsyncData(
            IpQuality(
              ip: '2.2.2.2',
              source: IpQualitySource.identMe,
              type: good ? IpType.residential : IpType.hosting,
            ),
          ),
        ),
      ],
    );
  }

  test('selected target supplies the badge and its quality', () async {
    answers(ProbePhase.fresh, good: true);
    await container.read(klashMonitorTargetProvider.notifier).select('Manual');
    await show(tun: true);
    final badge = host.lastShown!.image.badge!;
    expect(
      (badge.country, badge.status, badge.highQuality),
      ('JP', 'tun', true),
    );
    expect(host.lastShown!.image.pngs, isEmpty);
    expect(host.lastShown!.toolTip, contains('2.2.2.2'));
  });

  test(
    'stopped, failed and entry colors remain independent of quality',
    () async {
      for (final (running, phase, tun, proxy, status) in [
        (false, ProbePhase.fresh, true, true, 'stopped'),
        (true, ProbePhase.failed, true, true, 'failed'),
        (true, ProbePhase.fresh, true, true, 'tun'),
        (true, ProbePhase.fresh, false, true, 'route'),
        (true, ProbePhase.fresh, false, false, 'entry'),
      ]) {
        answers(phase, good: true);
        await container
            .read(klashMonitorTargetProvider.notifier)
            .select('Manual');
        await show(running: running, tun: tun, proxy: proxy);
        final badge = host.lastShown!.image.badge!;
        expect(badge.status, status);
        expect(
          badge.country,
          running && phase == ProbePhase.fresh ? 'JP' : '--',
        );
      }
    },
  );

  test('safe mode uses the upstream icon without a monitoring badge', () async {
    await show(safe: true);
    expect(host.lastShown!.image.badge, isNull);
    expect(host.lastShown!.image.pngs, isNotEmpty);
  });

  test(
    'group and node monitor actions do not change proxy selection',
    () async {
      const groups = [
        Group(
          name: 'Manual',
          type: GroupType.Selector,
          all: [
            Proxy(name: 'Auto', type: 'URLTest'),
            Proxy(name: 'Japan', type: 'SS'),
          ],
        ),
      ];
      await show(groups: groups);
      final group = host.lastShown!.menu.firstWhere(
        (item) => item.label == 'Manual',
      );
      final before = container.read(selectedMapProvider);
      for (final item in [group, ...group.items]) {
        final accessory = item.accessory!;
        expect(accessory.id, isNot(item.id));
        host.emit(TraySignalKind.itemSelected, accessory.id);
        await Future<void>.delayed(Duration.zero);
        expect(container.read(klashMonitorTargetProvider), item.label);
        expect(container.read(selectedMapProvider), before);
      }
    },
  );

  test('badge changes invalidate the unchanged-payload cache', () async {
    answers(ProbePhase.fresh);
    await show();
    await container.read(klashMonitorTargetProvider.notifier).select('Manual');
    await show();
    expect(host.shown, hasLength(2));
    expect(host.shown.map((item) => item.image.badge!.country), ['US', 'JP']);
  });
}
