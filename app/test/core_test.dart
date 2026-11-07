import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jinja_mine/core/market.dart';
import 'package:jinja_mine/core/miner.dart';
import 'package:jinja_mine/core/settings.dart';
import 'package:jinja_mine/core/wallet.dart';
import 'package:shared_preferences/shared_preferences.dart';

// A syntactically valid mainnet address (the Monero project's general donation address).
const addr = '44AFFq5kSiGBoZ4NMDwYtN18obc8AemS33DBLWs3H7otXft3XjrpDtQGv7SqSsaBYBb98uNbr2VBBEt7f2wfn3RVGQBEP3A';

void main() {
  test('address check', () {
    expect(checkMoneroAddress(addr).ok, isTrue);
    expect(checkMoneroAddress('0x03182c249b5ef9aba45d921c0a487e801f3ed4b5').ok, isFalse);
    expect(checkMoneroAddress('${addr}x').ok, isFalse);
    expect(checkMoneroAddress(addr.replaceFirst('4', '8')).ok, isFalse); // right format, wrong checksum
    expect(checkMoneroAddress(addr.replaceRange(10, 11, '0')).ok, isFalse); // 0 is not base58
  });

  test('cpu affinity: physical cores first', () {
    expect(cpuAffinity(4, 32), [0, 2, 4, 6]);
    expect(cpuAffinity(18, 32).sublist(15), [30, 1, 3]);
    expect(cpuAffinity(40, 32), hasLength(32));
    expect(cpuAffinity(3, 3), [0, 1, 2]);
  });

  test('earnings math', () {
    final m = MarketService()
      ..difficulty = 874733378368
      ..blockReward = 0.6008
      ..priceTry = 31977
      ..priceUsd = 639;
    final perDay = m.xmrPerDay(22000)!;
    expect(perDay, closeTo(0.0013055, 0.000005));
    final e = Earnings.compute(m: m, hashrate: 22000, days: 1, poolFeePct: 0.6, watts: 150, tlPerKwh: 3)!;
    expect(e.kwh, closeTo(3.6, 1e-9));
    expect(e.powerTry, closeTo(10.8, 1e-9));
    expect(e.grossTry, closeTo(perDay * 0.994 * 31977, 1e-6));
  });

  test('config + fake xmrig end to end', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    await s.load();
    final fake = '${Directory.current.path}\\build\\fake_xmrig.exe';
    expect(File(fake).existsSync(), isTrue, reason: 'run: dart compile exe tool/fake_xmrig.dart -o build/fake_xmrig.exe');
    s.update(() {
      s.wallet = addr;
      s.xmrigPath = fake;
      s.threads = 8;
      s.apiPort = 18123;
      s.pauseOnGames = false;
    });
    final m = MinerController(s);
    expect(m.problems(), isEmpty);
    final cfg = m.buildConfig(8);
    expect((cfg['cpu'] as Map)['rx'], [0, 2, 4, 6, 8, 10, 12, 14]);
    expect(((cfg['pools'] as List).first as Map)['url'], 'pool.supportxmr.com:443');
    expect(((cfg['pools'] as List).first as Map)['user'], addr);

    await m.start();
    for (int i = 0; i < 40 && m.state != MinerState.running; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    expect(m.state, MinerState.running);
    await Future<void>.delayed(const Duration(seconds: 3));
    expect(m.summary!.hr10s, 8 * 650.0);
    expect(m.summary!.accepted, greaterThan(0));
    expect(m.summary!.hugePages, [8, 8]);

    await m.pause('elle');
    expect(m.state, MinerState.paused);
    await Future<void>.delayed(const Duration(seconds: 3));
    expect(m.summary!.paused, isTrue);
    expect(m.state, MinerState.paused);
    await m.resume();
    expect(m.state, MinerState.running);

    s.update(() => s.threads = 4);
    await m.applyLive();
    await Future<void>.delayed(const Duration(seconds: 3));
    expect(m.summary!.threadCount, 4);
    expect(m.currentThreads, 4);

    await m.stop();
    expect(m.state, MinerState.stopped);
    expect(m.logs.any((l) => l.text.contains('accepted')), isTrue);
    expect(m.logs.any((l) => l.text.contains('XMRig beklenmedik')), isFalse);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
