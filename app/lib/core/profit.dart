import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'market.dart';
import 'pools.dart';
import 'settings.dart';

/// Can JinjaMine run this option right now?
enum Runnable {
  ready, // can be selected and mined now
  needsAddress, // can be mined after entering an address for its payout
  advanced, // needs extra software (own node, other miner, other coin's pool)
  infoOnly, // shown for comparison, XMRig cannot mine it
}

/// One "what to mine, where" option with its estimated daily result at our hash rate.
class ProfitOption {
  ProfitOption({
    required this.id,
    required this.coin,
    required this.title,
    required this.where,
    required this.algorithm,
    required this.payoutCoin,
    required this.feePct,
    required this.ratio,
    required this.ratio24,
    required this.runnable,
    required this.note,
    this.poolId,
    this.liquidityBtc,
    this.pingMs,
    this.payoutDays,
    this.uncertain = false,
  });

  final String id, coin, title, where, algorithm, payoutCoin, note;
  final String? poolId; // set when JinjaMine can switch to it
  final double feePct;
  final double ratio, ratio24; // revenue relative to solo-equivalent XMR mining at the same hash rate
  final Runnable runnable;
  final bool uncertain; // estimate from one source that disagrees with others: never recommended or auto-chosen
  final double? liquidityBtc; // 24 h exchange volume of the coin
  int? pingMs;
  double? payoutDays;

  // filled by ProfitService.compute
  double grossTry = 0, grossTry24 = 0, powerTry = 0;
  double get netTry => grossTry - powerTry;
  double get netTry24 => grossTry24 - powerTry;

  bool get thinMarket => liquidityBtc != null && liquidityBtc! < 0.5;
}

enum ProfitSort { net, net24, fee, payout, ping, liquidity }

extension ProfitSortText on ProfitSort {
  String get title => switch (this) {
        ProfitSort.net => 'En kârlı (şu an)',
        ProfitSort.net24 => 'En kârlı (24 sa ortalama)',
        ProfitSort.fee => 'En düşük ücret',
        ProfitSort.payout => 'En hızlı ödeme',
        ProfitSort.ping => 'En düşük gecikme',
        ProfitSort.liquidity => 'En kolay satılır (likidite)',
      };
}

/// Ranks what to mine and where, from WhatToMine's CPU list (relative revenues of all CPU coins, refreshed every
/// few minutes there), Monero network numbers and pool latency measured from this PC.
class ProfitService extends ChangeNotifier {
  ProfitService(this.settings, this.market);
  final AppSettings settings;
  final MarketService market;

  List<ProfitOption> options = [];
  DateTime? updatedAt;
  String? error;
  bool loading = false;
  double? btcTry;
  final Map<String, double> coinTry = {}; // TL price per payout coin
  double? umThreshold; // unMineable payout threshold, in the payout coin
  static const _geckoIds = {'BTC': 'bitcoin', 'TRX': 'tron', 'LTC': 'litecoin', 'DOGE': 'dogecoin', 'USDT': 'tether', 'XMR': 'monero'};
  double hashrate = 0; // H/s used for the last computation
  Timer? _timer;
  final Map<String, int?> _ping = {};
  Map<String, dynamic>? _wtm;

  /// Fired by [refresh] when automatic switching decides to move to another pool.
  void Function(String poolId, String reason)? onSwitch;
  String? _pendingSwitch;

  void startAuto() {
    refresh();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 30), (_) => refresh());
  }

  Future<void> refresh() async {
    if (loading) return;
    loading = true;
    error = null;
    notifyListeners();
    final errs = <String>[];
    try {
      final r = await http.get(Uri.parse('https://whattomine.com/cpu.json'), headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
      _wtm = (jsonDecode(r.body) as Map<String, dynamic>)['coins'] as Map<String, dynamic>;
    } catch (e) {
      errs.add('WhatToMine: $e');
    }
    try {
      final ids = _geckoIds.values.join(',');
      final r = await http.get(Uri.parse('https://api.coingecko.com/api/v3/simple/price?ids=$ids&vs_currencies=try')).timeout(const Duration(seconds: 20));
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      _geckoIds.forEach((sym, id) {
        final v = (j[id] as Map?)?['try'];
        if (v is num) coinTry[sym] = v.toDouble();
      });
      btcTry = coinTry['BTC'];
    } catch (e) {
      errs.add('coin fiyatları: $e');
    }
    try {
      final r = await http.get(Uri.parse('https://api.unminable.com/v4/coin/${settings.umCoin}')).timeout(const Duration(seconds: 20));
      final d = (jsonDecode(r.body) as Map<String, dynamic>)['data'] as Map<String, dynamic>;
      umThreshold = double.tryParse('${d['payment_threshold']}');
    } catch (_) {
      umThreshold = null;
    }
    if (market.difficulty == null) await market.refresh();
    await _measurePings();
    if (errs.isNotEmpty) error = errs.join(' · ');
    updatedAt = DateTime.now();
    loading = false;
    compute();
    _considerSwitch();
  }

  Future<void> _measurePings() async {
    await Future.wait([
      for (final p in pools.where((p) => p.url.isNotEmpty && !p.host.startsWith('127.')))
        () async {
          final sw = Stopwatch()..start();
          try {
            final s = await Socket.connect(p.host, p.port, timeout: const Duration(seconds: 4));
            s.destroy();
            _ping[p.id] = sw.elapsedMilliseconds;
          } catch (_) {
            _ping[p.id] = null;
          }
        }(),
    ]);
  }

  /// WhatToMine revenue of [name] relative to Monero (same hash rate for RandomX coins; WhatToMine's typical CPU
  /// speeds for other algorithms).
  (double, double, double?)? _rel(String name) {
    final c = _wtm?[name] as Map<String, dynamic>?;
    final x = _wtm?['Monero'] as Map<String, dynamic>?;
    if (c == null || x == null) return null;
    double n(Map m, String k) => double.tryParse('${m[k]}') ?? 0;
    final base = n(x, 'btc_revenue'), base24 = n(x, 'btc_revenue24');
    if (base <= 0) return null;
    return (n(c, 'btc_revenue') / base, base24 > 0 ? n(c, 'btc_revenue24') / base24 : n(c, 'btc_revenue') / base, (c['exchange_rate_vol'] as num?)?.toDouble());
  }

  void compute() {
    final hr = hashrate > 0 ? hashrate : settings.manualHashrate;
    final xmrDay = market.xmrPerDay(hr);
    final price = market.priceTry;
    final xmrVol = _rel('Monero')?.$3;
    final out = <ProfitOption>[];

    String addrState(String pool) => settings.payoutAddress(pool).isEmpty ? 'adres gerekli' : 'adres hazır';
    for (final p in pools.where((p) => p.payout == Payout.xmr && p.id != 'custom')) {
      out.add(ProfitOption(
        id: 'xmr-${p.id}',
        coin: 'XMR',
        title: 'Monero (XMR)',
        where: p.name,
        algorithm: 'RandomX',
        payoutCoin: 'XMR',
        feePct: p.feePct,
        ratio: 1,
        ratio24: 1,
        poolId: p.id,
        liquidityBtc: xmrVol,
        runnable: p.advanced ? Runnable.advanced : (settings.wallet.trim().isEmpty ? Runnable.needsAddress : Runnable.ready),
        note: p.advanced ? 'Kendi Monero düğümün ve p2pool gerekir.' : 'XMR cüzdanına ödeme · ${addrState(p.id)}',
      ));
    }
    out.add(ProfitOption(
      id: 'unmineable',
      coin: settings.umCoin,
      title: 'RandomX → ${settings.umCoin}',
      where: 'unMineable',
      algorithm: 'RandomX',
      payoutCoin: settings.umCoin,
      feePct: 1.0,
      ratio: 1,
      ratio24: 1,
      poolId: 'unmineable',
      runnable: settings.umAddress.trim().isEmpty ? Runnable.needsAddress : Runnable.ready,
      note: 'Binance’a doğrudan ödeme (${payoutCoinBy(settings.umCoin).network}) · ${addrState('unmineable')}',
    ));
    final nh = _rel('Nicehash-RandomX');
    if (nh != null) {
      out.add(ProfitOption(
        id: 'nicehash',
        coin: 'BTC',
        title: 'Hash gücünü kirala → BTC',
        where: 'NiceHash',
        algorithm: 'RandomX',
        payoutCoin: 'BTC',
        feePct: 2.0,
        ratio: nh.$1,
        ratio24: nh.$2,
        poolId: 'nicehash',
        uncertain: true,
        runnable: settings.nhAddress.trim().isEmpty ? Runnable.needsAddress : Runnable.ready,
        note: 'Tahmin belirsiz: WhatToMine ile NiceHash API’si farklı fiyat veriyor, NiceHash hesaplayıcısıyla doğrula · ${addrState('nicehash')}',
      ));
    }
    // Other CPU coins, for comparison. XMRig mines RandomX/GhostRider coins but each needs its own pool and wallet.
    const others = {
      'Etica': ('ETI', 'RandomX (ETI)', Runnable.advanced, 'Özel madenci/havuz ve ETI cüzdanı gerekir.'),
      'EPIC-RandomX': ('EPIC', 'RandomX (Epic)', Runnable.infoOnly, 'Epic Cash kendi madencisini ister.'),
      'Zephyr': ('ZEPH', 'RandomX', Runnable.advanced, 'XMRig ile kazılır; ZEPH havuzu ve cüzdanı gerekir (Özel havuz).'),
      'Quantum R L': ('QRL', 'RandomX', Runnable.advanced, 'QRL havuzu ve cüzdanı gerekir (Özel havuz).'),
      'Dagger': ('XDAG', 'RandomX (XDAG)', Runnable.infoOnly, 'XDAG kendi madencisini ister.'),
      'Tari-RandomX': ('XTM', 'RandomX (Tari)', Runnable.advanced, 'Tari havuzu ve cüzdanı gerekir.'),
      'Raptoreum': ('RTM', 'GhostRider', Runnable.advanced, 'XMRig ile kazılır (algo gr); RTM havuzu ve cüzdanı gerekir.'),
      'Verus': ('VRSC', 'VerusHash', Runnable.infoOnly, 'XMRig desteklemez (ccminer/hellminer).'),
      'Xelis': ('XEL', 'XelisHash', Runnable.infoOnly, 'XMRig desteklemez.'),
    };
    others.forEach((name, v) {
      final r = _rel(name);
      if (r == null) return;
      out.add(ProfitOption(
        id: 'coin-${v.$1}',
        coin: v.$1,
        title: name.replaceAll('-RandomX', ''),
        where: 'kendi havuzu',
        algorithm: v.$2,
        payoutCoin: v.$1,
        feePct: 1.0,
        ratio: r.$1,
        ratio24: r.$2,
        liquidityBtc: r.$3,
        runnable: v.$3,
        note: v.$4,
      ));
    });

    for (final o in out) {
      o.pingMs = o.poolId == null ? null : _ping[o.poolId];
      if (xmrDay != null && price != null) {
        final keep = 1 - o.feePct / 100;
        o.grossTry = xmrDay * o.ratio * keep * price;
        o.grossTry24 = xmrDay * o.ratio24 * keep * price;
      }
      o.powerTry = settings.extraWatts / 1000 * 24 * settings.electricityTlPerKwh;
      final pool = o.poolId == null ? null : poolById(o.poolId!);
      if (pool != null && pool.payout == Payout.xmr && pool.minPayout > 0 && xmrDay != null && xmrDay > 0) {
        o.payoutDays = pool.minPayout / (xmrDay * (1 - pool.feePct / 100));
      } else if (o.id == 'unmineable' && o.grossTry > 0 && umThresholdTry() != null) {
        o.payoutDays = umThresholdTry()! / o.grossTry;
      }
    }
    options = out;
    notifyListeners();
  }

  /// unMineable payout threshold converted to TL (null when the threshold or price is unknown).
  double? umThresholdTry() {
    final t = umThreshold, p = coinTry[settings.umCoin];
    return t == null || p == null ? null : t * p;
  }

  List<ProfitOption> sorted(ProfitSort s) {
    final l = [...options];
    int cmpNull(num? a, num? b, {bool asc = true}) {
      if (a == null && b == null) return 0;
      if (a == null) return 1;
      if (b == null) return -1;
      return asc ? a.compareTo(b) : b.compareTo(a);
    }

    l.sort((a, b) => switch (s) {
          ProfitSort.net => b.netTry.compareTo(a.netTry),
          ProfitSort.net24 => b.netTry24.compareTo(a.netTry24),
          ProfitSort.fee => a.feePct.compareTo(b.feePct),
          ProfitSort.payout => cmpNull(a.payoutDays, b.payoutDays),
          ProfitSort.ping => cmpNull(a.pingMs, b.pingMs),
          ProfitSort.liquidity => cmpNull(a.liquidityBtc, b.liquidityBtc, asc: false),
        });
    return l;
  }

  /// Best option JinjaMine can actually run (with or without an address yet); liquid markets only.
  /// Ties within 0.1 % are broken by latency (a fee difference outweighs a few ms).
  ProfitOption? get recommended {
    final c = options.where((o) => o.poolId != null && (o.runnable == Runnable.ready || o.runnable == Runnable.needsAddress) && !o.thinMarket && !o.uncertain).toList();
    if (c.isEmpty) return null;
    c.sort((a, b) {
      final d = b.netTry - a.netTry;
      if (d.abs() > 0.001 * a.grossTry.abs()) return d > 0 ? 1 : -1;
      return (a.pingMs ?? 9999).compareTo(b.pingMs ?? 9999);
    });
    return c.first;
  }

  /// Best option that is ready now (its address is set).
  ProfitOption? get bestReady {
    final c = options.where((o) => o.poolId != null && o.runnable == Runnable.ready && !o.uncertain).toList()..sort((a, b) => b.netTry.compareTo(a.netTry));
    return c.isEmpty ? null : c.first;
  }

  ProfitOption? optionFor(String poolId) {
    for (final o in options) {
      if (o.poolId == poolId) return o;
    }
    return null;
  }

  /// Automatic switching: only between routes whose address is set, only when the best is ≥ 5 % better on both
  /// the current price and the 24 h average, and only after two refreshes in a row agree (avoids flapping).
  void _considerSwitch() {
    if (!settings.autoSwitch) return;
    final best = bestReady, cur = optionFor(settings.poolId);
    if (best == null || cur == null || best.poolId == settings.poolId) {
      _pendingSwitch = null;
      return;
    }
    final better = best.grossTry > cur.grossTry * 1.05 && best.grossTry24 > cur.grossTry24 * 1.05;
    if (!better) {
      _pendingSwitch = null;
      return;
    }
    if (_pendingSwitch == best.poolId) {
      _pendingSwitch = null;
      onSwitch?.call(best.poolId!, '${best.where} ${((best.grossTry / cur.grossTry - 1) * 100).toStringAsFixed(0)} % daha kârlı');
    } else {
      _pendingSwitch = best.poolId;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
