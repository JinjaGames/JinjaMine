// ignore_for_file: avoid_print
// Runs only with MINE_LIVE=1: hits the real WhatToMine / xmrchain / CoinGecko / pool APIs.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jinja_mine/core/market.dart';
import 'package:jinja_mine/core/pool_stats.dart';
import 'package:jinja_mine/core/profit.dart';
import 'package:jinja_mine/core/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final live = Platform.environment['MINE_LIVE'] == '1';
  test('live ranking and balances', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    await s.load();
    s.update(() {
      s.wallet = '44AFFq5kSiGBoZ4NMDwYtN18obc8AemS33DBLWs3H7otXft3XjrpDtQGv7SqSsaBYBb98uNbr2VBBEt7f2wfn3RVGQBEP3A';
      s.poolId = 'moneroocean';
      s.umAddress = 'TLa2f6VPqDgRE67v1736s7bJ8Ray5wYjU7';
    });
    final mk = MarketService();
    await mk.refresh();
    print('market: diff ${mk.difficulty} reward ${mk.blockReward} price ${mk.priceTry} err ${mk.error}');
    final p = ProfitService(s, mk)..hashrate = 9800;
    await p.refresh();
    print('profit err: ${p.error} umThreshold ${p.umThreshold} prices ${p.coinTry}');
    for (final o in p.sorted(ProfitSort.net)) {
      print('${o.title.padRight(26)} ${o.where.padRight(16)} gross ${o.grossTry.toStringAsFixed(2).padLeft(7)} net ${o.netTry.toStringAsFixed(2).padLeft(7)} '
          'fee ${o.feePct} ping ${o.pingMs} payout ${o.payoutDays?.toStringAsFixed(1)} liq ${o.liquidityBtc?.toStringAsFixed(2)} ${o.runnable.name}${o.uncertain ? ' UNCERTAIN' : ''}${o.thinMarket ? ' THIN' : ''}');
    }
    print('recommended: ${p.recommended?.id}');
    expect(p.options.length, greaterThan(8));
    s.rememberPayout();
    s.update(() => s.poolId = 'supportxmr');
    s.rememberPayout();
    s.update(() => s.poolId = 'unmineable');
    final ps = PoolStatsService(s);
    await ps.refreshAll();
    for (final e in ps.entries) {
      print('${e.poolId} ${e.coin}: due ${e.due} paid ${e.paid} hr ${e.poolHashrate} pays ${e.payments.length} err ${e.error} supported ${e.supported}');
    }
  }, skip: !live, timeout: const Timeout(Duration(minutes: 2)));
}
