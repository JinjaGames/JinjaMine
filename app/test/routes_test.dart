import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jinja_mine/core/hardware.dart';
import 'package:jinja_mine/core/market.dart';
import 'package:jinja_mine/core/miner.dart';
import 'package:jinja_mine/core/pools.dart';
import 'package:jinja_mine/core/profit.dart';
import 'package:jinja_mine/core/settings.dart';
import 'package:jinja_mine/core/wallet.dart';
import 'package:shared_preferences/shared_preferences.dart';

const addr = '44AFFq5kSiGBoZ4NMDwYtN18obc8AemS33DBLWs3H7otXft3XjrpDtQGv7SqSsaBYBb98uNbr2VBBEt7f2wfn3RVGQBEP3A';

Future<AppSettings> fresh() async {
  SharedPreferences.setMockInitialValues({});
  final s = AppSettings();
  await s.load();
  return s;
}

void main() {
  test('address checksum catches a typo', () {
    expect(checkMoneroAddress(addr).ok, isTrue);
    final typo = addr.replaceRange(30, 31, addr[30] == 'k' ? 'm' : 'k');
    final c = checkMoneroAddress(typo);
    expect(c.ok, isFalse);
    expect(c.message, contains('sağlama'));
  });

  test('unMineable and NiceHash configs', () async {
    final s = await fresh();
    s.update(() {
      s.poolId = 'unmineable';
      s.umCoin = 'TRX';
      s.umAddress = 'TLa2f6VPqDgRE67v1736s7bJ8Ray5wYjU7';
      s.worker = 'pc1';
      s.xmrigPath = Platform.resolvedExecutable;
    });
    final m = MinerController(s);
    expect(m.problems(), isEmpty);
    var pool = (m.buildConfig(4)['pools'] as List).first as Map;
    expect(pool['url'], 'rx.unmineable.com:443');
    expect(pool['user'], 'TRX:TLa2f6VPqDgRE67v1736s7bJ8Ray5wYjU7.pc1');
    expect(pool['algo'], 'rx/0');
    expect(pool['tls'], isTrue);

    s.update(() => s.umAddress = '0x1234');
    expect(m.problems().single, contains('TRX adresi geçersiz'));

    s.update(() {
      s.poolId = 'nicehash';
      s.nhAddress = 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq';
    });
    expect(m.problems(), isEmpty);
    pool = (m.buildConfig(4)['pools'] as List).first as Map;
    expect(pool['nicehash'], isTrue);
    expect(pool['user'], 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq.pc1');

    s.update(() => s.poolId = 'supportxmr');
    expect(m.problems().single, startsWith('Cüzdan'));
    s.update(() => s.wallet = addr);
    expect(m.problems(), isEmpty);
    expect(s.payoutCoinOf(), 'XMR');
  });

  test('profit ranking without network data: fee decides among XMR routes', () async {
    final s = await fresh();
    s.update(() {
      s.wallet = addr;
      s.extraWatts = 150;
      s.electricityTlPerKwh = 3;
    });
    final mk = MarketService()
      ..difficulty = 866368259071
      ..blockReward = 0.63
      ..priceTry = 31680;
    final p = ProfitService(s, mk)..hashrate = 20000;
    p.compute();
    final best = p.sorted(ProfitSort.net).first;
    expect(best.where, 'MoneroOcean'); // 0 % fee
    final sx = p.optionFor('supportxmr')!;
    expect(sx.grossTry, closeTo(20000 * 86400 / 866368259071 * 0.63 * 0.994 * 31680, 1e-6));
    expect(sx.powerTry, closeTo(10.8, 1e-9));
    expect(p.recommended!.poolId, 'moneroocean');
    expect(p.optionFor('unmineable')!.runnable, Runnable.needsAddress);
    expect(p.optionFor('p2pool')!.runnable, Runnable.advanced);
  });

  test('temperature levels and LibreHardwareMonitor parsing', () {
    expect(HardwareMonitor.levelFor(null, 90, cool: 50), TempLevel.unknown);
    expect(HardwareMonitor.levelFor(40, 90, cool: 50), TempLevel.cool);
    expect(HardwareMonitor.levelFor(70, 90, cool: 50), TempLevel.normal);
    expect(HardwareMonitor.levelFor(82, 90, cool: 50), TempLevel.warm);
    expect(HardwareMonitor.levelFor(91, 90, cool: 50), TempLevel.hot);
    final json = {
      'Text': 'Sensor',
      'Children': [
        {
          'Text': 'DESKTOP',
          'Children': [
            {
              'Text': 'AMD Ryzen 9 7950X',
              'ImageURL': 'images_icon/cpu.png',
              'Children': [
                {
                  'Text': 'Temperatures',
                  'Children': [
                    {'Text': 'Core (Tctl/Tdie)', 'Value': '78,5 °C', 'Children': []},
                    {'Text': 'CCD1 (Tdie)', 'Value': '74.0 °C', 'Children': []},
                  ],
                },
              ],
            },
            {
              'Text': 'NVIDIA GeForce RTX 5070 Ti',
              'ImageURL': 'images_icon/nvidia.png',
              'Children': [
                {'Text': 'GPU Core', 'Value': '50.0 °C', 'Children': []},
              ],
            },
          ],
        },
      ],
    };
    expect(HardwareMonitor.cpuTempFromLhmJson(json), 78.5);
    expect(HardwareMonitor.pickCpuTemp({'CPU Package': 81, 'Core #1': 70}), 81);
  });

  test('payout history remembers routes', () async {
    final s = await fresh();
    s.update(() => s.wallet = addr);
    s.rememberPayout();
    s.rememberPayout();
    expect(s.usedPayouts, hasLength(1));
    s.update(() {
      s.poolId = 'unmineable';
      s.umAddress = 'TLa2f6VPqDgRE67v1736s7bJ8Ray5wYjU7';
    });
    s.rememberPayout();
    expect(s.usedPayouts, hasLength(2));
    expect(poolById('unmineable').payout, Payout.anyCoin);
  });
}
