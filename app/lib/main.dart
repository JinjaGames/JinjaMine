import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'core/hardware.dart';
import 'core/market.dart';
import 'core/miner.dart';
import 'core/pool_stats.dart';
import 'core/pools.dart';
import 'core/profit.dart';
import 'core/settings.dart';
import 'core/system.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';
import 'ui/widgets.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  for (final a in args) {
    if (a.startsWith('--page=')) initialPage = int.tryParse(a.substring(7)) ?? 0;
  }
  await migrateLegacyData();
  final settings = AppSettings();
  await settings.load();
  // Empty, or the folder was moved/renamed (e.g. Desktop\mine -> Desktop\JinjaMine): look for xmrig again.
  if (settings.xmrigPath.isEmpty || !File(settings.xmrigPath).existsSync()) {
    final f = findXmrig();
    if (f != null) settings.update(() => settings.xmrigPath = f);
  }
  final miner = MinerController(settings);
  final market = MarketService()..startAuto();
  final poolStats = PoolStatsService(settings)..startAuto();
  final hardware = HardwareMonitor(settings)..start();
  final profit = ProfitService(settings, market);
  // Hooks: the controller asks for the reward per hash, the CPU temperature and the current route's net result.
  miner.xmrPerHash = () {
    final d = market.difficulty, r = market.blockReward;
    return d == null || r == null || d <= 0 ? null : r / d;
  };
  miner.cpuTemp = () => hardware.cpuTemp;
  miner.netTryPerDay = () {
    final o = profit.optionFor(settings.poolId);
    return o == null || o.grossTry <= 0 ? null : o.netTry;
  };
  // Recompute the ranking with the measured hash rate (cheap, no network) when the 15-min average moves.
  miner.addListener(() {
    final h = miner.summary?.hr15m ?? miner.summary?.hr60s ?? 0;
    if (h > 0 && (h - profit.hashrate).abs() > profit.hashrate * 0.05) {
      profit.hashrate = h;
      profit.compute();
    }
  });
  market.addListener(() {
    if (market.difficulty != null && !profit.loading) profit.compute();
  });
  profit.onSwitch = (poolId, reason) async {
    if (poolId == settings.poolId) return;
    miner.log('Otomatik geçiş: ${poolById(poolId).name} ($reason).', LogKind.ok);
    settings.update(() => settings.poolId = poolId);
    poolStats.refresh();
    if (miner.busy) await miner.restart();
  };
  profit.startAuto();
  runApp(AppScope(state: AppState(settings, miner, market, poolStats, hardware, profit), child: JinjaMineApp(miner: miner)));
  final autostart = args.contains('--autostart');
  if ((settings.startMiningOnLaunch || autostart) && miner.problems().isEmpty) {
    miner.start();
  }
}

class JinjaMineApp extends StatefulWidget {
  const JinjaMineApp({super.key, required this.miner});
  final MinerController miner;
  @override
  State<JinjaMineApp> createState() => _JinjaMineAppState();
}

class _JinjaMineAppState extends State<JinjaMineApp> {
  late final AppLifecycleListener _life;

  @override
  void initState() {
    super.initState();
    // Closing the window must never leave xmrig running in the background.
    _life = AppLifecycleListener(onExitRequested: () async {
      await widget.miner.stop(reason: 'Uygulama kapatılıyor.');
      return AppExitResponse.exit;
    });
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'JinjaMine',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const Shell(),
      );
}
