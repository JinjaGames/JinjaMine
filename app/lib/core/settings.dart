import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// When the miner is allowed to work.
enum RunMode { always, idleOnly, adaptive }

extension RunModeText on RunMode {
  String get title => switch (this) {
        RunMode.always => 'Her zaman tam güç',
        RunMode.idleOnly => 'Yalnızca bilgisayar boştayken',
        RunMode.adaptive => 'Uyarlamalı (kullanırken hafif)',
      };
  String get help => switch (this) {
        RunMode.always => 'Ayarladığın iş parçacığı sayısıyla sürekli çalışır.',
        RunMode.idleOnly => 'Klavye/fare belirli bir süre kullanılmayınca başlar, dokununca duraklar.',
        RunMode.adaptive => 'Sen kullanırken az iş parçacığıyla, boştayken tam güçle çalışır.',
      };
}

/// Every setting of the app, saved with shared_preferences.
class AppSettings extends ChangeNotifier {
  late SharedPreferences _p;

  // --- wallet & pool
  String wallet = '';
  String poolId = 'supportxmr';
  String customUrl = '';
  bool customTls = true;
  String worker = 'jinjamine';
  bool walletIsLocal = false; // wallet = address of the wallet JinjaMine created on this PC
  String umCoin = 'TRX'; // unMineable payout coin
  String umAddress = '';
  String nhAddress = ''; // NiceHash mining (BTC) address

  // --- profit
  bool autoSwitch = false; // switch between the configured routes when another is clearly better
  bool profitGuard = false; // pause while electricity costs more than the mining earns

  // --- temperature
  bool tempGuard = true;
  int cpuTempLimit = 90; // °C; the 7950X's own limit is 95
  int gpuTempLimit = 83;

  // --- balances: every (pool, address, coin) mined to, so old balances stay visible after switching
  List<String> usedPayouts = [];
  double minedXmrEst = 0; // XMR-equivalent mined through this app (estimate from accepted work)
  double minedHashes = 0;

  // --- miner
  String xmrigPath = '';
  int threads = max(1, Platform.numberOfProcessors * 3 ~/ 4); // 24 on the 7950X: best measured without huge pages
  int idleThreads = max(1, Platform.numberOfProcessors * 3 ~/ 4);
  int activeThreads = max(1, Platform.numberOfProcessors ~/ 4);
  int priority = 1; // 0 idle .. 5 highest
  bool hugePages = true;
  bool oneGbPages = false;
  bool msr = true;
  int donateLevel = 1; // XMRig's minimum in official builds
  int apiPort = 18088;

  // --- schedule
  RunMode mode = RunMode.always;
  int idleMinutes = 3;
  bool pauseOnGames = true;
  List<String> gameExes = ['cs2.exe', 'LeagueClient.exe', 'League of Legends.exe', 'RocketLeague.exe', 'Brawlhalla.exe', 'VALORANT-Win64-Shipping.exe', 'javaw.exe'];
  bool startMiningOnLaunch = false;

  // --- earnings
  double electricityTlPerKwh = 3.0;
  double extraWatts = 150;
  double poolFeePct = 0.6;
  double manualHashrate = 9800; // measured on this PC (XMRig 6.26.0, 24 threads, no huge pages)

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    wallet = _p.getString('wallet') ?? wallet;
    poolId = _p.getString('poolId') ?? poolId;
    customUrl = _p.getString('customUrl') ?? customUrl;
    customTls = _p.getBool('customTls') ?? customTls;
    worker = _p.getString('worker') ?? worker;
    walletIsLocal = _p.getBool('walletIsLocal') ?? walletIsLocal;
    umCoin = _p.getString('umCoin') ?? umCoin;
    umAddress = _p.getString('umAddress') ?? umAddress;
    nhAddress = _p.getString('nhAddress') ?? nhAddress;
    autoSwitch = _p.getBool('autoSwitch') ?? autoSwitch;
    profitGuard = _p.getBool('profitGuard') ?? profitGuard;
    tempGuard = _p.getBool('tempGuard') ?? tempGuard;
    cpuTempLimit = _p.getInt('cpuTempLimit') ?? cpuTempLimit;
    gpuTempLimit = _p.getInt('gpuTempLimit') ?? gpuTempLimit;
    usedPayouts = _p.getStringList('usedPayouts') ?? usedPayouts;
    minedXmrEst = _p.getDouble('minedXmrEst') ?? minedXmrEst;
    minedHashes = _p.getDouble('minedHashes') ?? minedHashes;
    xmrigPath = _p.getString('xmrigPath') ?? xmrigPath;
    threads = _p.getInt('threads') ?? threads;
    idleThreads = _p.getInt('idleThreads') ?? idleThreads;
    activeThreads = _p.getInt('activeThreads') ?? activeThreads;
    priority = _p.getInt('priority') ?? priority;
    hugePages = _p.getBool('hugePages') ?? hugePages;
    oneGbPages = _p.getBool('oneGbPages') ?? oneGbPages;
    msr = _p.getBool('msr') ?? msr;
    donateLevel = _p.getInt('donateLevel') ?? donateLevel;
    apiPort = _p.getInt('apiPort') ?? apiPort;
    mode = RunMode.values[(_p.getInt('mode') ?? 0).clamp(0, RunMode.values.length - 1)];
    idleMinutes = _p.getInt('idleMinutes') ?? idleMinutes;
    pauseOnGames = _p.getBool('pauseOnGames') ?? pauseOnGames;
    gameExes = _p.getStringList('gameExes') ?? gameExes;
    startMiningOnLaunch = _p.getBool('startOnLaunch') ?? startMiningOnLaunch;
    electricityTlPerKwh = _p.getDouble('kwh') ?? electricityTlPerKwh;
    extraWatts = _p.getDouble('watts') ?? extraWatts;
    poolFeePct = _p.getDouble('poolFee') ?? poolFeePct;
    manualHashrate = _p.getDouble('manualHash') ?? manualHashrate;
    _clamp();
  }

  void _clamp() {
    final n = Platform.numberOfProcessors;
    threads = threads.clamp(1, n);
    idleThreads = idleThreads.clamp(1, n);
    activeThreads = activeThreads.clamp(1, n);
    priority = priority.clamp(0, 5);
    donateLevel = donateLevel.clamp(1, 100);
    idleMinutes = idleMinutes.clamp(1, 120);
    apiPort = apiPort.clamp(1024, 65535);
    cpuTempLimit = cpuTempLimit.clamp(60, 95);
    gpuTempLimit = gpuTempLimit.clamp(60, 90);
  }

  /// The address the current pool pays to ('' when not set).
  String payoutAddress([String? pool]) => switch (pool ?? poolId) {
        'unmineable' => umAddress.trim(),
        'nicehash' => nhAddress.trim(),
        _ => wallet.trim(),
      };

  String payoutCoinOf([String? pool]) => switch (pool ?? poolId) {
        'unmineable' => umCoin,
        'nicehash' => 'BTC',
        _ => 'XMR',
      };

  /// Remembers that we mined to this pool/address so its balance stays listed after switching.
  void rememberPayout() {
    final a = payoutAddress();
    if (a.isEmpty) return;
    final key = jsonEncode({'pool': poolId, 'address': a, 'coin': payoutCoinOf()});
    if (usedPayouts.contains(key)) return;
    update(() => usedPayouts = [...usedPayouts, key]);
  }

  /// Saves counters without notifying listeners (called often while mining).
  void saveLedger() {
    _p.setDouble('minedXmrEst', minedXmrEst);
    _p.setDouble('minedHashes', minedHashes);
  }

  void update(void Function() change) {
    change();
    _clamp();
    _p.setString('wallet', wallet);
    _p.setString('poolId', poolId);
    _p.setString('customUrl', customUrl);
    _p.setBool('customTls', customTls);
    _p.setString('worker', worker);
    _p.setBool('walletIsLocal', walletIsLocal);
    _p.setString('umCoin', umCoin);
    _p.setString('umAddress', umAddress);
    _p.setString('nhAddress', nhAddress);
    _p.setBool('autoSwitch', autoSwitch);
    _p.setBool('profitGuard', profitGuard);
    _p.setBool('tempGuard', tempGuard);
    _p.setInt('cpuTempLimit', cpuTempLimit);
    _p.setInt('gpuTempLimit', gpuTempLimit);
    _p.setStringList('usedPayouts', usedPayouts);
    _p.setDouble('minedXmrEst', minedXmrEst);
    _p.setDouble('minedHashes', minedHashes);
    _p.setString('xmrigPath', xmrigPath);
    _p.setInt('threads', threads);
    _p.setInt('idleThreads', idleThreads);
    _p.setInt('activeThreads', activeThreads);
    _p.setInt('priority', priority);
    _p.setBool('hugePages', hugePages);
    _p.setBool('oneGbPages', oneGbPages);
    _p.setBool('msr', msr);
    _p.setInt('donateLevel', donateLevel);
    _p.setInt('apiPort', apiPort);
    _p.setInt('mode', mode.index);
    _p.setInt('idleMinutes', idleMinutes);
    _p.setBool('pauseOnGames', pauseOnGames);
    _p.setStringList('gameExes', gameExes);
    _p.setBool('startOnLaunch', startMiningOnLaunch);
    _p.setDouble('kwh', electricityTlPerKwh);
    _p.setDouble('watts', extraWatts);
    _p.setDouble('poolFee', poolFeePct);
    _p.setDouble('manualHash', manualHashrate);
    notifyListeners();
  }
}
