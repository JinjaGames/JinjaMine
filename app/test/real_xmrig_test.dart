// ignore_for_file: avoid_print
// Runs only when MINE_REAL_XMRIG points at a real xmrig.exe. Uses an unreachable local pool on purpose,
// so nothing is mined: it checks that XMRig accepts the generated config and that the API calls work.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jinja_mine/core/miner.dart';
import 'package:jinja_mine/core/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

const addr = '44AFFq5kSiGBoZ4NMDwYtN18obc8AemS33DBLWs3H7otXft3XjrpDtQGv7SqSsaBYBb98uNbr2VBBEt7f2wfn3RVGQBEP3A';

void main() {
  final path = Platform.environment['MINE_REAL_XMRIG'];
  test('real xmrig accepts config and API', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    await s.load();
    s.update(() {
      s.wallet = addr;
      s.xmrigPath = path!;
      s.poolId = 'custom';
      s.customUrl = '127.0.0.1:9';
      s.customTls = false;
      s.threads = 4;
      s.apiPort = 18124;
      s.pauseOnGames = false;
    });
    final m = MinerController(s);
    await m.start();
    for (int i = 0; i < 60 && m.state != MinerState.running; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    expect(m.state, MinerState.running, reason: m.logs.map((l) => l.text).join('\n'));
    expect(m.summary!.version, startsWith('6.'));
    print('version ${m.summary!.version}, cpu ${m.summary!.cpuBrand}, pool ${m.summary!.pool}, donate ${m.summary!.donate}');

    await m.pause('elle');
    expect(m.state, MinerState.paused);
    await Future<void>.delayed(const Duration(seconds: 3));
    expect(m.summary!.paused, isTrue);
    await m.resume();
    expect(m.state, MinerState.running);

    s.update(() => s.threads = 6);
    await m.applyLive();
    expect(m.currentThreads, 6);
    expect(m.logs.any((l) => l.text.contains('canlı uygulandı')), isTrue, reason: m.logs.map((l) => l.text).join('\n'));

    await m.stop();
    expect(m.state, MinerState.stopped);
    final lines = m.logs.where((l) => l.kind == LogKind.miner || l.kind == LogKind.warn || l.kind == LogKind.error).map((l) => l.text).toList();
    print(lines.take(40).join('\n'));
  }, skip: path == null ? 'MINE_REAL_XMRIG not set' : false, timeout: const Timeout(Duration(minutes: 2)));
}
