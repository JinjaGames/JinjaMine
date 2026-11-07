import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'pools.dart';
import 'settings.dart';

class Payment {
  Payment(this.at, this.amount, this.tx, this.url);
  final DateTime at;
  final double amount;
  final String tx;
  final String? url;
}

/// What one pool says about one payout address.
class BalanceEntry {
  BalanceEntry(this.poolId, this.address, this.coin);
  final String poolId, address, coin;
  double? due, paid, poolHashrate;
  int? validShares, invalidShares;
  DateTime? lastShare, updatedAt;
  String? error;
  bool supported = true;
  List<Payment> payments = [];

  PoolPreset get pool => poolById(poolId);
  String get key => '$poolId|$address|$coin';
}

/// Balances on every pool/address this app has mined to: pending ("havuzda bekleyen") and paid out ("cüzdana
/// aktarılan") with the payment list. Supports nodejs-pool (SupportXMR, MoneroOcean) and unMineable; others link
/// to their web panel.
class PoolStatsService extends ChangeNotifier {
  PoolStatsService(this.settings);
  final AppSettings settings;

  final Map<String, BalanceEntry> _entries = {};
  bool loading = false;
  Timer? _timer;

  List<BalanceEntry> get entries {
    final keys = <String>{};
    for (final raw in settings.usedPayouts) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        keys.add('${j['pool']}|${j['address']}|${j['coin']}');
      } catch (_) {}
    }
    final c = currentKey;
    if (c != null) keys.add(c);
    return [
      for (final k in keys)
        _entries.putIfAbsent(k, () {
          final p = k.split('|');
          return BalanceEntry(p[0], p[1], p[2]);
        }),
    ];
  }

  String? get currentKey {
    final a = settings.payoutAddress();
    return a.isEmpty ? null : '${settings.poolId}|$a|${settings.payoutCoinOf()}';
  }

  BalanceEntry? get current {
    final k = currentKey;
    if (k == null) return null;
    return entries.firstWhere((e) => e.key == k);
  }

  // Shortcuts used by the dashboard (current pool/address).
  double? get due => current?.due;
  double? get paid => current?.paid;
  double? get poolHashrate => current?.poolHashrate;
  int? get validShares => current?.validShares;
  int? get invalidShares => current?.invalidShares;
  DateTime? get lastShare => current?.lastShare;
  DateTime? get updatedAt => current?.updatedAt;
  String? get error => current?.error;
  String get coin => settings.payoutCoinOf();

  /// Paid-out total in XMR over every XMR pool/address.
  double get totalPaidXmr => entries.where((e) => e.coin == 'XMR').fold(0.0, (a, e) => a + (e.paid ?? 0));
  double get totalDueXmr => entries.where((e) => e.coin == 'XMR').fold(0.0, (a, e) => a + (e.due ?? 0));

  void startAuto() {
    refreshAll();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => refresh());
  }

  void clear() => notifyListeners();

  /// Current pool/address only.
  Future<void> refresh() async {
    final c = current;
    if (c == null || loading) return;
    loading = true;
    notifyListeners();
    await _load(c);
    loading = false;
    notifyListeners();
  }

  Future<void> refreshAll() async {
    if (loading) return;
    loading = true;
    notifyListeners();
    await Future.wait(entries.map(_load));
    loading = false;
    notifyListeners();
  }

  Future<dynamic> _get(String url) async {
    final r = await http.get(Uri.parse(url), headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 20));
    if (r.statusCode == 404) return null;
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    if (r.body.trim().isEmpty) return null;
    return jsonDecode(r.body);
  }

  Future<void> _load(BalanceEntry e) async {
    e.error = null;
    try {
      if (e.pool.statsApi != null) {
        await _nodejsPool(e);
      } else if (e.poolId == 'unmineable') {
        await _unmineable(e);
      } else {
        e.supported = false;
      }
      e.updatedAt = DateTime.now();
    } catch (err) {
      e.error = 'Okunamadı: $err';
    }
  }

  Future<void> _nodejsPool(BalanceEntry e) async {
    final base = e.pool.statsApi!;
    final j = await _get('$base/miner/${e.address}/stats') as Map<String, dynamic>?;
    if (j == null) {
      e.poolHashrate = 0;
      e.due = e.paid = 0;
      e.error = 'Havuz bu adresi henüz tanımıyor (ilk paylaşımdan sonra görünür).';
      return;
    }
    double n(String k) => (j[k] as num?)?.toDouble() ?? 0;
    e.poolHashrate = n('hash');
    e.due = n('amtDue') / 1e12;
    e.paid = n('amtPaid') / 1e12;
    e.validShares = (j['validShares'] as num?)?.toInt();
    e.invalidShares = (j['invalidShares'] as num?)?.toInt();
    final lh = (j['lastHash'] as num?)?.toInt() ?? 0;
    e.lastShare = lh > 0 ? DateTime.fromMillisecondsSinceEpoch(lh * 1000) : null;
    final pays = await _get('$base/miner/${e.address}/payments');
    if (pays is List) {
      e.payments = [
        for (final p in pays.cast<Map>())
          Payment(DateTime.fromMillisecondsSinceEpoch(((p['ts'] as num?) ?? 0).toInt() * 1000), ((p['amount'] as num?) ?? 0) / 1e12, '${p['txnHash'] ?? ''}',
              p['txnHash'] == null ? null : 'https://xmrchain.net/tx/${p['txnHash']}'),
      ];
    }
  }

  Future<void> _unmineable(BalanceEntry e) async {
    final a = await _get('https://api.unminable.com/v4/address/${e.address}?coin=${e.coin}') as Map<String, dynamic>?;
    final d = a?['data'] as Map<String, dynamic>?;
    if (d == null) throw Exception('adres bilinmiyor');
    e.due = double.tryParse('${d['balance']}') ?? 0;
    final uuid = d['uuid'];
    final st = await _get('https://api.unminable.com/v3/stats/${e.address}?coin=${e.coin}') as Map<String, dynamic>?;
    final sd = st?['data'] as Map<String, dynamic>?;
    if (sd != null) {
      e.paid = double.tryParse('${sd['total_paid']}') ?? 0;
      final rx = (sd['hashrate'] as Map?)?['randomx'] as Map?;
      e.poolHashrate = (rx?['totalh'] as num?)?.toDouble();
    }
    if (uuid != null) {
      final p = await _get('https://api.unminable.com/v4/account/$uuid/payments?page=1') as Map<String, dynamic>?;
      final pd = p?['data'] as Map<String, dynamic>?;
      final explorer = '${pd?['explorer'] ?? ''}';
      e.payments = [
        for (final x in ((pd?['list'] as List?) ?? const []).cast<Map>())
          () {
            final tx = '${x['tx'] ?? x['txid'] ?? x['tx_hash'] ?? ''}';
            final ts = x['timestamp'] ?? x['date'] ?? x['created_at'];
            final at = ts is num ? DateTime.fromMillisecondsSinceEpoch(ts > 1e12 ? ts.toInt() : ts.toInt() * 1000) : DateTime.tryParse('$ts') ?? DateTime.now();
            return Payment(at, double.tryParse('${x['amount']}') ?? 0, tx, tx.isEmpty || explorer.isEmpty ? null : '$explorer$tx');
          }(),
      ];
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
