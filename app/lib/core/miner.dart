import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'pools.dart';
import 'settings.dart';
import 'system.dart';
import 'wallet.dart';

/// Logical CPUs for [n] RandomX threads: one per physical core first (even indices), then the SMT siblings.
/// Measured on the 7950X: 12 pinned threads gave ~40 % more than 12 unpinned ones (the OS put pairs on one core).
List<int> cpuAffinity(int n, int logical) {
  final order = logical > 1 && logical.isEven
      ? [for (int i = 0; i < logical; i += 2) i, for (int i = 1; i < logical; i += 2) i]
      : [for (int i = 0; i < logical; i++) i];
  return order.take(n.clamp(1, logical)).toList();
}

enum MinerState { stopped, starting, running, paused, error }

enum LogKind { info, ok, warn, error, miner }

class LogLine {
  LogLine(this.kind, this.text) : at = DateTime.now();
  final LogKind kind;
  final String text;
  final DateTime at;
}

/// Parsed /2/summary of the XMRig HTTP API.
class MinerSummary {
  MinerSummary(this.raw);
  final Map<String, dynamic> raw;

  T? _at<T>(List<Object> path) {
    dynamic v = raw;
    for (final k in path) {
      if (v is Map && k is String) {
        v = v[k];
      } else if (v is List && k is int) {
        v = k < v.length ? v[k] : null;
      } else {
        return null;
      }
    }
    return v is T ? v : null;
  }

  double? hr(int i) => _at<num>(['hashrate', 'total', i])?.toDouble();
  double? get hr10s => hr(0);
  double? get hr60s => hr(1);
  double? get hr15m => hr(2);
  double? get highest => _at<num>(['hashrate', 'highest'])?.toDouble();
  int get threadCount => (_at<List>(['hashrate', 'threads']) ?? const []).length;
  int get accepted => _at<num>(['connection', 'accepted'])?.toInt() ?? 0;
  int get rejected => _at<num>(['connection', 'rejected'])?.toInt() ?? 0;
  int get sharesGood => _at<num>(['results', 'shares_good'])?.toInt() ?? 0;
  int get sharesTotal => _at<num>(['results', 'shares_total'])?.toInt() ?? 0;
  int get hashesTotal => _at<num>(['results', 'hashes_total'])?.toInt() ?? 0;
  int get diff => _at<num>(['connection', 'diff'])?.toInt() ?? 0;
  int get ping => _at<num>(['connection', 'ping'])?.toInt() ?? 0;
  int get poolUptime => _at<num>(['connection', 'uptime'])?.toInt() ?? 0;
  int get uptime => _at<num>(['uptime'])?.toInt() ?? 0;
  String get pool => _at<String>(['connection', 'pool']) ?? '—';
  String get algo => _at<String>(['algo']) ?? '—';
  String get version => _at<String>(['version']) ?? '—';
  String get cpuBrand => _at<String>(['cpu', 'brand']) ?? '—';
  bool get paused => _at<bool>(['paused']) ?? false;
  bool get msr => _at<bool>(['cpu', 'msr']) ?? false;
  int get donate => _at<num>(['donate_level'])?.toInt() ?? 0;

  /// [allocated, total] huge pages, or null when unknown.
  List<int>? get hugePages {
    final h = _at<List>(['hugepages']);
    if (h == null || h.length < 2) return null;
    return [(h[0] as num).toInt(), (h[1] as num).toInt()];
  }
}

/// Starts XMRig as a child process, configures it through a generated config.json, watches it through its local
/// HTTP API and applies the schedule (idle / adaptive / pause while games run).
class MinerController extends ChangeNotifier {
  MinerController(this.settings);
  final AppSettings settings;

  MinerState state = MinerState.stopped;
  String? pauseReason;
  MinerSummary? summary;
  DateTime? startedAt;
  final List<LogLine> logs = [];
  final List<(DateTime, double)> history = []; // 10 s hashrate samples
  int restarts = 0;
  bool elevated = false;
  int currentThreads = 0;
  int idleSec = 0;
  String? activeGame;

  // --- hooks set by main.dart (kept as callbacks so the controller stays testable)
  double? Function()? xmrPerHash; // network reward / difficulty
  double? Function()? cpuTemp; // °C or null
  double? Function()? netTryPerDay; // current route's net daily result, null when unknown

  // --- protections and tuning
  int? thermalCap; // max threads while the CPU is too hot
  DateTime? _hotSince, _coolSince;
  double sessionXmrEst = 0;
  int _lastHashes = 0;
  DateTime _lastLedgerSave = DateTime.now();
  AutoTune? tune;

  // Timings (shortened by tests).
  static Duration tuneSettle = const Duration(seconds: 25), tuneSampleEvery = const Duration(seconds: 2);
  static int tuneSamples = 15, hotHoldSec = 20, coolHoldSec = 120;

  Process? _proc;
  Timer? _poll, _sched;
  final String _token = _randomToken();
  Map<String, dynamic>? _config;
  bool _stopping = false;
  int _apiFailures = 0;
  DateTime _lastHistory = DateTime.fromMillisecondsSinceEpoch(0);
  bool _rpcBusy = false;

  static String _randomToken() {
    final r = Random.secure();
    return List.generate(24, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  bool get busy => state == MinerState.running || state == MinerState.starting || state == MinerState.paused;
  double get hashrate => summary?.hr10s ?? summary?.hr60s ?? 0;

  void log(String t, [LogKind k = LogKind.info]) {
    logs.add(LogLine(k, t));
    if (logs.length > 3000) logs.removeRange(0, logs.length - 3000);
    notifyListeners();
  }

  // ------------------------------------------------------------------ checks
  /// Everything that would stop a start, in plain language. Empty = ready.
  List<String> problems() {
    final out = <String>[];
    final p = poolById(settings.poolId);
    switch (p.payout) {
      case Payout.xmr:
        final w = checkMoneroAddress(settings.wallet);
        if (!w.ok) out.add('Cüzdan: ${w.message}');
      case Payout.anyCoin:
        final c = payoutCoinBy(settings.umCoin);
        if (settings.umAddress.trim().isEmpty) {
          out.add('Cüzdan: unMineable için ${c.symbol} ödeme adresi girilmedi.');
        } else if (!c.valid(settings.umAddress)) {
          out.add('Cüzdan: ${c.symbol} adresi geçersiz görünüyor (${c.network} ağı adresi olmalı).');
        }
      case Payout.btcNiceHash:
        if (!validBtcAddress(settings.nhAddress)) out.add('Cüzdan: NiceHash madencilik (BTC) adresi girilmedi ya da geçersiz.');
    }
    if (p.id == 'custom' && !RegExp(r'^[\w.-]+:\d+$').hasMatch(settings.customUrl.trim())) {
      out.add('Özel havuz adresi “sunucu:port” biçiminde olmalı.');
    }
    if (settings.xmrigPath.isEmpty || !File(settings.xmrigPath).existsSync()) {
      out.add('xmrig.exe bulunamadı. Kurulum sayfasından XMRig’i indirip yolunu seç.');
    }
    return out;
  }

  Future<String> sha256Of(String path) async => sha256.convert(await File(path).readAsBytes()).toString();

  // ------------------------------------------------------------------ config
  Map<String, dynamic> buildConfig(int threads) {
    final p = poolById(settings.poolId);
    final url = p.id == 'custom' ? settings.customUrl.trim() : p.url;
    final tls = p.id == 'custom' ? settings.customTls : p.tls;
    final worker = settings.worker.trim().isEmpty ? 'jinjamine' : settings.worker.trim().replaceAll(RegExp(r'[^\w.-]'), '_');
    return {
      'api': {'id': null, 'worker-id': worker},
      'http': {'enabled': true, 'host': '127.0.0.1', 'port': settings.apiPort, 'access-token': _token, 'restricted': false},
      'autosave': false,
      'background': false,
      'colors': false,
      'title': false,
      'randomx': {
        'init': -1,
        'init-avx2': -1,
        'mode': 'auto',
        '1gb-pages': settings.oneGbPages,
        'rdmsr': true,
        'wrmsr': settings.msr,
        'cache_qos': false,
        'numa': true,
        'scratchpad_prefetch_mode': 1,
      },
      'cpu': {
        'enabled': true,
        'huge-pages': settings.hugePages,
        'huge-pages-jit': false,
        'hw-aes': null,
        'priority': settings.priority,
        'memory-pool': false,
        'yield': true,
        'asm': true,
        'rx': cpuAffinity(threads, Platform.numberOfProcessors),
      },
      'opencl': {'enabled': false},
      'cuda': {'enabled': false},
      'donate-level': settings.donateLevel,
      'donate-over-proxy': 1,
      'log-file': null,
      'pools': [
        {
          'algo': p.payout == Payout.xmr ? null : 'rx/0',
          'coin': p.payout == Payout.xmr ? 'monero' : null,
          'url': url,
          'user': switch (p.payout) {
            Payout.anyCoin => '${settings.umCoin}:${settings.umAddress.trim()}.$worker',
            Payout.btcNiceHash => '${settings.nhAddress.trim()}.$worker',
            Payout.xmr => p.id == 'p2pool' ? worker : settings.wallet.trim(),
          },
          'pass': p.payout != Payout.xmr ? 'x' : (p.passIsWorker ? worker : 'x'),
          'rig-id': worker,
          'nicehash': p.payout == Payout.btcNiceHash,
          'keepalive': true,
          'enabled': true,
          'tls': tls,
          'daemon': false,
        }
      ],
      'print-time': 60,
      'health-print-time': 60,
      'retries': 5,
      'retry-pause': 5,
      'syslog': false,
      'user-agent': null,
      'verbose': 0,
      'watch': false,
      'pause-on-battery': true,
      'pause-on-active': false,
    };
  }

  String get configPath => '${dataDir().path}\\config.json';

  // ------------------------------------------------------------------ start / stop
  Future<void> start() async {
    if (busy) return;
    final probs = problems();
    if (probs.isNotEmpty) {
      for (final p in probs) {
        log(p, LogKind.error);
      }
      state = MinerState.error;
      notifyListeners();
      return;
    }
    _stopping = false;
    state = MinerState.starting;
    pauseReason = null;
    summary = null;
    _apiFailures = 0;
    notifyListeners();
    elevated = await isElevated();
    settings.rememberPayout();
    _lastHashes = 0;
    thermalCap = null;
    _hotSince = _coolSince = null;
    await _killOrphans();
    currentThreads = _wantedThreads(idleSeconds());
    _config = buildConfig(currentThreads);
    await File(configPath).writeAsString(const JsonEncoder.withIndent('  ').convert(_config));
    final pool = (_config!['pools'] as List).first as Map;
    log('Başlatılıyor: ${pool['url']} (${pool['tls'] == true ? 'TLS' : 'şifresiz'}), $currentThreads iş parçacığı, öncelik ${settings.priority}, '
        '${elevated ? 'yönetici' : 'normal kullanıcı'} olarak.');
    if (!elevated && (settings.hugePages || settings.msr)) {
      log('Not: Huge pages ve MSR ayarı en iyi yönetici izniyle çalışır (Kurulum → “Yönetici olarak yeniden başlat”). Onsuz da kazar, ~%10–30 daha yavaş.', LogKind.warn);
    }
    try {
      _proc = await Process.start(settings.xmrigPath, ['--config', configPath], workingDirectory: File(settings.xmrigPath).parent.path);
    } catch (e) {
      log('XMRig başlatılamadı: $e', LogKind.error);
      log('Antivirüs xmrig.exe’yi silmiş ya da engellemiş olabilir (madencilik programları “PUA/CoinMiner” diye işaretlenir). Belgeler → 03_KURULUM.', LogKind.warn);
      state = MinerState.error;
      notifyListeners();
      return;
    }
    startedAt = DateTime.now();
    final proc = _proc!;
    proc.stdout.transform(const SystemEncoding().decoder).transform(const LineSplitter()).listen(_onLine);
    proc.stderr.transform(const SystemEncoding().decoder).transform(const LineSplitter()).listen((l) => _onLine(l, err: true));
    proc.exitCode.then((code) => _onExit(proc, code));
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _pollApi());
    _sched?.cancel();
    _sched = Timer.periodic(const Duration(seconds: 5), (_) => _schedule());
    notifyListeners();
  }

  Future<void> stop({String reason = 'Durduruldu.'}) async {
    _stopping = true;
    tune?.cancelled = true;
    settings.saveLedger();
    _poll?.cancel();
    _sched?.cancel();
    final p = _proc;
    _proc = null;
    if (p != null) {
      p.kill();
      try {
        await p.exitCode.timeout(const Duration(seconds: 4));
      } catch (_) {
        await Process.run('taskkill', ['/F', '/T', '/PID', '${p.pid}']);
      }
    }
    if (state != MinerState.stopped) log(reason);
    state = MinerState.stopped;
    pauseReason = null;
    summary = null;
    notifyListeners();
  }

  Future<void> restart() async {
    await stop(reason: 'Yeniden başlatılıyor…');
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await start();
  }

  Future<void> _killOrphans() async {
    // An xmrig left behind by a crash of this app would hold the API port and the CPU.
    final path = settings.xmrigPath.replaceAll("'", "''");
    await Process.run('powershell', [
      '-NoProfile',
      '-Command',
      "Get-Process xmrig -ErrorAction SilentlyContinue | Where-Object { \$_.Path -eq '$path' } | Stop-Process -Force",
    ]);
  }

  void _onLine(String l, {bool err = false}) {
    final t = l.trimRight();
    if (t.isEmpty) return;
    final low = t.toLowerCase();
    var k = err ? LogKind.warn : LogKind.miner;
    if (low.contains('accepted')) {
      k = LogKind.ok;
    } else if (low.contains('rejected') || low.contains('error') || low.contains('failed')) {
      k = LogKind.error;
    } else if (low.contains('warn') || low.contains('unavailable') || low.contains('disabled')) {
      k = LogKind.warn;
    }
    log(t, k);
  }

  void _onExit(Process p, int code) {
    if (!identical(p, _proc) && _proc != null) return;
    if (_stopping) return;
    _proc = null;
    _poll?.cancel();
    _sched?.cancel();
    summary = null;
    log('XMRig beklenmedik şekilde kapandı (çıkış kodu $code).', LogKind.error);
    if (restarts < 5) {
      restarts++;
      state = MinerState.starting;
      log('10 saniye sonra yeniden başlatılacak (deneme $restarts/5).', LogKind.warn);
      notifyListeners();
      Future<void>.delayed(const Duration(seconds: 10), () {
        if (!_stopping && state == MinerState.starting && _proc == null) {
          state = MinerState.stopped;
          start();
        }
      });
    } else {
      state = MinerState.error;
      log('Çok kez kapandı; otomatik yeniden başlatma bırakıldı. Günlükteki son satırlara bak.', LogKind.error);
      notifyListeners();
    }
  }

  // ------------------------------------------------------------------ API
  Map<String, String> get _auth => {'Authorization': 'Bearer $_token', 'Content-Type': 'application/json'};
  String get _base => 'http://127.0.0.1:${settings.apiPort}';

  Future<void> _pollApi() async {
    if (_proc == null) return;
    try {
      final r = await http.get(Uri.parse('$_base/2/summary'), headers: _auth).timeout(const Duration(seconds: 3));
      if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
      summary = MinerSummary(jsonDecode(r.body) as Map<String, dynamic>);
      _apiFailures = 0;
      if (state == MinerState.starting) {
        state = MinerState.running;
        restarts = 0;
        log('XMRig çalışıyor (${summary!.version}, ${summary!.cpuBrand}).', LogKind.ok);
      }
      if (summary!.paused && state == MinerState.running) state = MinerState.paused;
      if (!summary!.paused && state == MinerState.paused && pauseReason == null) state = MinerState.running;
      _account(summary!);
      final now = DateTime.now();
      if (now.difference(_lastHistory).inSeconds >= 10) {
        _lastHistory = now;
        history.add((now, summary!.hr10s ?? 0));
        if (history.length > 8640) history.removeRange(0, history.length - 8640); // 24 h
      }
      notifyListeners();
    } catch (_) {
      _apiFailures++;
      if (_apiFailures == 15 && state == MinerState.starting) {
        log('XMRig API’si 30 sn’dir yanıt vermiyor. Port ${settings.apiPort} başka bir program tarafından kullanılıyor olabilir (Ayarlar → API portu).', LogKind.warn);
      }
    }
  }

  /// Adds the hashes done since the last poll to the lifetime counters, valued at the current network reward.
  void _account(MinerSummary sm) {
    final h = sm.hashesTotal;
    if (h < _lastHashes) _lastHashes = 0; // XMRig restarted
    final delta = h - _lastHashes;
    _lastHashes = h;
    if (delta <= 0) return;
    final per = xmrPerHash?.call();
    final keep = (1 - poolById(settings.poolId).feePct / 100) * (1 - settings.donateLevel / 100);
    final x = per == null ? 0.0 : delta * per * keep;
    sessionXmrEst += x;
    settings.minedHashes += delta;
    settings.minedXmrEst += x;
    if (DateTime.now().difference(_lastLedgerSave).inSeconds >= 60) {
      _lastLedgerSave = DateTime.now();
      settings.saveLedger();
    }
  }

  Future<bool> _rpc(String method) async {
    try {
      final r = await http
          .post(Uri.parse('$_base/json_rpc'), headers: _auth, body: jsonEncode({'method': method, 'id': 1, 'jsonrpc': '2.0'}))
          .timeout(const Duration(seconds: 4));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _putConfig(Map<String, dynamic> cfg) async {
    try {
      final r = await http.put(Uri.parse('$_base/1/config'), headers: _auth, body: jsonEncode(cfg)).timeout(const Duration(seconds: 5));
      return r.statusCode >= 200 && r.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<void> pause(String reason) async {
    if (_proc == null || _rpcBusy) return;
    _rpcBusy = true;
    if (await _rpc('pause')) {
      state = MinerState.paused;
      pauseReason = reason;
      log('Duraklatıldı: $reason');
    }
    _rpcBusy = false;
    notifyListeners();
  }

  Future<void> resume() async {
    if (_proc == null || _rpcBusy) return;
    _rpcBusy = true;
    if (await _rpc('resume')) {
      state = MinerState.running;
      log('Devam ediyor${pauseReason == null ? '' : ' ($pauseReason sona erdi)'}.');
      pauseReason = null;
    }
    _rpcBusy = false;
    notifyListeners();
  }

  /// Applies the current settings to the running miner without restarting it.
  Future<void> applyLive() async {
    if (_proc == null) return;
    final t = _wantedThreads(idleSeconds());
    final cfg = buildConfig(t);
    await File(configPath).writeAsString(const JsonEncoder.withIndent('  ').convert(cfg));
    if (await _putConfig(cfg)) {
      _config = cfg;
      currentThreads = t;
      log('Ayarlar canlı uygulandı ($t iş parçacığı).', LogKind.ok);
    } else {
      log('Ayarlar canlı uygulanamadı; yeniden başlatılıyor.', LogKind.warn);
      await restart();
    }
  }

  // ------------------------------------------------------------------ schedule
  int _wantedThreads(int idle) {
    if (tune != null && !tune!.done) return tune!.current;
    final cap = thermalCap;
    final want = _baseThreads(idle);
    return cap == null ? want : min(want, cap);
  }

  int _baseThreads(int idle) {
    final isIdle = idle >= settings.idleMinutes * 60;
    return switch (settings.mode) {
      RunMode.always => settings.threads,
      RunMode.idleOnly => settings.idleThreads,
      RunMode.adaptive => isIdle ? settings.idleThreads : settings.activeThreads,
    };
  }

  /// Temperature guard: above the limit for 20 s -> 25 % fewer threads (repeats while still hot);
  /// 8 °C below the limit for 2 minutes -> the cap is lifted step by step.
  void _thermal() {
    final t = cpuTemp?.call();
    if (!settings.tempGuard || t == null) {
      if (!settings.tempGuard) thermalCap = null;
      return;
    }
    final now = DateTime.now();
    final limit = settings.cpuTempLimit;
    if (t >= limit) {
      _coolSince = null;
      _hotSince ??= now;
      if (now.difference(_hotSince!).inSeconds >= hotHoldSec) {
        final base = thermalCap ?? currentThreads;
        final next = max(1, (base * 0.75).floor());
        if (next < base) {
          thermalCap = next;
          log('Sıcaklık koruması: işlemci ${t.toStringAsFixed(0)} °C (sınır $limit °C) → $next iş parçacığına inildi.', LogKind.warn);
        }
        _hotSince = now; // next step after another 20 s
      }
    } else if (thermalCap != null && t <= limit - 8) {
      _hotSince = null;
      _coolSince ??= now;
      if (now.difference(_coolSince!).inSeconds >= coolHoldSec) {
        final full = _baseThreads(idleSec);
        final int next = min(full, thermalCap! + max(1, full ~/ 8));
        thermalCap = next >= full ? null : next;
        log(thermalCap == null ? 'Sıcaklık normale döndü: sınırlama kaldırıldı.' : 'İşlemci serinledi (${t.toStringAsFixed(0)} °C): $next iş parçacığına çıkılıyor.', LogKind.ok);
        _coolSince = now;
      }
    } else {
      _hotSince = null;
    }
  }

  Future<void> _schedule() async {
    if (_proc == null || state == MinerState.starting) return;
    idleSec = idleSeconds();
    final isIdle = idleSec >= settings.idleMinutes * 60;

    // 1) games
    String? game;
    if (settings.pauseOnGames && settings.gameExes.isNotEmpty) {
      final running = await runningExes();
      for (final g in settings.gameExes) {
        if (running.contains(g.toLowerCase())) {
          game = g;
          break;
        }
      }
    }
    activeGame = game;
    if (pauseReason == 'elle') {
      notifyListeners();
      return; // a manual pause wins over the schedule
    }

    String? wantPause;
    final net = settings.profitGuard ? netTryPerDay?.call() : null;
    if (game != null) {
      wantPause = 'oyun açık ($game)';
    } else if (settings.mode == RunMode.idleOnly && !isIdle) {
      wantPause = 'bilgisayar kullanılıyor';
    } else if (net != null && net < 0) {
      wantPause = 'zararına: elektrik kazançtan pahalı';
    }

    if (wantPause != null && state != MinerState.paused) {
      await pause(wantPause);
    } else if (wantPause != null && state == MinerState.paused && pauseReason != wantPause) {
      pauseReason = wantPause;
    } else if (wantPause == null && state == MinerState.paused && pauseReason != null) {
      await resume();
    }

    // 2) thread count: adaptive mode and the temperature guard (auto-tune sets its own)
    _thermal();
    if (state == MinerState.running && (tune == null || tune!.done)) {
      final want = _wantedThreads(idleSec);
      if (want != currentThreads) {
        final cfg = buildConfig(want);
        if (await _putConfig(cfg)) {
          if (thermalCap == null && settings.mode == RunMode.adaptive) {
            log(want > currentThreads ? 'Bilgisayar boşta: $want iş parçacığına çıkıldı.' : 'Bilgisayar kullanılıyor: $want iş parçacığına inildi.');
          }
          currentThreads = want;
          _config = cfg;
        }
      }
    }
    notifyListeners();
  }

  // ------------------------------------------------------------------ auto-tune
  /// Tries several thread counts on the running miner (live, no restart) and keeps the fastest.
  /// Each step: 25 s to settle, then the 10 s hash rate is averaged for 30 s.
  Future<void> autoTune() async {
    if (state != MinerState.running || (tune != null && !tune!.done)) return;
    final n = Platform.numberOfProcessors;
    final cands = <int>{for (final f in [0.5, 0.625, 0.75, 0.875, 1.0]) max(1, (n * f).round())}.toList()..sort();
    final t = tune = AutoTune(cands);
    log('Otomatik hız ayarı başladı: ${cands.join(', ')} iş parçacığı denenecek (~${(cands.length * 55 / 60).ceil()} dk).');
    notifyListeners();
    for (final c in cands) {
      if (t.cancelled || _proc == null) break;
      t.current = c;
      if (!await _putConfig(buildConfig(c))) {
        log('Otomatik ayar: XMRig ayarı kabul etmedi, durduruldu.', LogKind.warn);
        break;
      }
      currentThreads = c;
      notifyListeners();
      final settleEnd = DateTime.now().add(tuneSettle);
      while (!t.cancelled && DateTime.now().isBefore(settleEnd)) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final samples = <double>[];
      for (int i = 0; i < tuneSamples && !t.cancelled; i++) {
        await Future<void>.delayed(tuneSampleEvery);
        final h = summary?.hr10s;
        if (h != null && h > 0 && state == MinerState.running) samples.add(h);
      }
      if (t.cancelled) break;
      final hot = settings.tempGuard && (cpuTemp?.call() ?? 0) >= settings.cpuTempLimit;
      if (samples.isNotEmpty) {
        final avg = samples.reduce((a, b) => a + b) / samples.length;
        if (!hot) t.results[c] = avg;
        log('  $c iş parçacığı: ${(avg / 1000).toStringAsFixed(2)} kH/s${hot ? ' (sıcaklık sınırında, sayılmadı)' : ''}');
      }
      t.tried++;
      notifyListeners();
    }
    t.done = true;
    if (t.results.isNotEmpty && !t.cancelled) {
      final best = t.results.entries.reduce((a, b) => b.value > a.value * 1.01 ? b : a); // fewer threads on a tie
      settings.update(() {
        settings.threads = best.key;
        settings.idleThreads = best.key;
      });
      t.best = best.key;
      log('Otomatik ayar bitti: en hızlısı ${best.key} iş parçacığı (${(best.value / 1000).toStringAsFixed(2)} kH/s). Ayar kaydedildi.', LogKind.ok);
    } else {
      log(t.cancelled ? 'Otomatik ayar iptal edildi.' : 'Otomatik ayar sonuç alamadı.', LogKind.warn);
    }
    if (_proc != null) {
      final want = _wantedThreads(idleSec);
      if (await _putConfig(buildConfig(want))) currentThreads = want;
    }
    notifyListeners();
  }

  void cancelTune() {
    tune?.cancelled = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _sched?.cancel();
    _proc?.kill();
    super.dispose();
  }
}

class AutoTune {
  AutoTune(this.candidates) : current = candidates.first;
  final List<int> candidates;
  final Map<int, double> results = {};
  int current;
  int tried = 0;
  int? best;
  bool done = false, cancelled = false;
  double get progress => done ? 1 : tried / candidates.length;
}
