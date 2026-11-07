import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Live Monero network numbers and the XMR price, used for the earnings estimate.
class MarketService extends ChangeNotifier {
  double? difficulty; // network difficulty of the last block
  double? networkHashrate; // H/s
  double? blockReward; // XMR (coinbase of the last block: base reward + fees)
  int? height;
  double? priceUsd, priceTry;
  DateTime? updatedAt;
  String? error;
  bool loading = false;
  Timer? _timer;

  static const _blockTime = 120.0; // seconds
  static const _atomic = 1e12;

  void startAuto() {
    refresh();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 10), (_) => refresh());
  }

  Future<Map<String, dynamic>> _json(String url) async {
    final r = await http.get(Uri.parse(url), headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) throw Exception('$url → ${r.statusCode}');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<void> refresh() async {
    if (loading) return;
    loading = true;
    error = null;
    notifyListeners();
    final errs = <String>[];
    try {
      final info = (await _json('https://xmrchain.net/api/networkinfo'))['data'] as Map<String, dynamic>;
      difficulty = double.parse('${info['difficulty']}');
      networkHashrate = (info['hash_rate'] as num).toDouble();
      height = info['height'] as int;
      final blk = (await _json('https://xmrchain.net/api/block/${height! - 1}'))['data'] as Map<String, dynamic>;
      final cb = (blk['txs'] as List).cast<Map>().firstWhere((t) => t['coinbase'] == true);
      blockReward = (cb['xmr_outputs'] as num).toDouble() / _atomic;
    } catch (e) {
      errs.add('ağ bilgisi: $e');
      blockReward ??= 0.6; // tail emission, used only when the explorer is unreachable
    }
    try {
      final p = (await _json('https://api.coingecko.com/api/v3/simple/price?ids=monero&vs_currencies=usd,try'))['monero'] as Map<String, dynamic>;
      priceUsd = (p['usd'] as num).toDouble();
      priceTry = (p['try'] as num).toDouble();
    } catch (e) {
      errs.add('fiyat: $e');
    }
    if (errs.isNotEmpty) error = errs.join(' · ');
    updatedAt = DateTime.now();
    loading = false;
    notifyListeners();
  }

  /// Expected XMR per day for [hashrate] H/s (before pool fee).
  double? xmrPerDay(double hashrate) {
    if (difficulty == null || blockReward == null || difficulty! <= 0) return null;
    return hashrate * 86400 / difficulty! * blockReward!;
  }

  /// Mean time for a solo miner to find one block (for information only).
  double? soloDays(double hashrate) {
    if (difficulty == null || hashrate <= 0) return null;
    return difficulty! / hashrate / 86400;
  }

  double get blocksPerDay => 86400 / _blockTime;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Earnings for a period after pool fee and electricity.
class Earnings {
  Earnings({required this.xmr, required this.grossTry, required this.grossUsd, required this.powerTry, required this.kwh});
  final double xmr, grossTry, grossUsd, powerTry, kwh;
  double get netTry => grossTry - powerTry;

  static Earnings? compute({
    required MarketService m,
    required double hashrate,
    required double days,
    required double poolFeePct,
    required double watts,
    required double tlPerKwh,
  }) {
    final perDay = m.xmrPerDay(hashrate);
    if (perDay == null) return null;
    final xmr = perDay * days * (1 - poolFeePct / 100);
    final kwh = watts / 1000 * 24 * days;
    return Earnings(
      xmr: xmr,
      grossTry: xmr * (m.priceTry ?? 0),
      grossUsd: xmr * (m.priceUsd ?? 0),
      powerTry: kwh * tlPerKwh,
      kwh: kwh,
    );
  }
}
