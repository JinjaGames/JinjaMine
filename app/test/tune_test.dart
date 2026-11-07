import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jinja_mine/core/miner.dart';
import 'package:jinja_mine/core/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

const addr = '44AFFq5kSiGBoZ4NMDwYtN18obc8AemS33DBLWs3H7otXft3XjrpDtQGv7SqSsaBYBb98uNbr2VBBEt7f2wfn3RVGQBEP3A';

void main() {
  test('auto-tune, temperature guard and mined counter with fake xmrig', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    await s.load();
    s.update(() {
      s.wallet = addr;
      s.xmrigPath = '${Directory.current.path}/build/fake_xmrig.exe';
      s.threads = 8;
      s.apiPort = 18125;
      s.pauseOnGames = false;
    });
    MinerController.tuneSettle = const Duration(milliseconds: 2500);
    MinerController.tuneSampleEvery = const Duration(milliseconds: 300);
    MinerController.tuneSamples = 3;
    MinerController.hotHoldSec = 0;
    final m = MinerController(s);
    double temp = 60;
    m.cpuTemp = () => temp;
    m.xmrPerHash = () => 0.6 / 860e9;
    await m.start();
    for (int i = 0; i < 40 && m.state != MinerState.running; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    expect(m.state, MinerState.running, reason: m.logs.map((l) => l.text).join(' | '));

    await m.autoTune(); // fake hash rate = 650 H/s per thread -> more threads always faster
    final n = Platform.numberOfProcessors;
    expect(m.tune!.done, isTrue);
    expect(m.tune!.best, n);
    expect(s.threads, n);
    expect(m.currentThreads, n);
    expect(m.sessionXmrEst, greaterThan(0));
    expect(s.minedXmrEst, greaterThan(0));

    temp = 96; // too hot: the scheduler (every 5 s) must cut threads by 25 %
    for (int i = 0; i < 60 && m.thermalCap == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    expect(m.thermalCap, (n * 0.75).floor());
    for (int i = 0; i < 40 && m.currentThreads != m.thermalCap; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    expect(m.currentThreads, m.thermalCap);
    expect(m.logs.any((l) => l.text.contains('Sıcaklık koruması')), isTrue);
    await m.stop();
  }, timeout: const Timeout(Duration(minutes: 3)));
}
