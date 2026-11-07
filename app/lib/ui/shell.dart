import 'package:flutter/material.dart';

import '../core/hardware.dart';
import '../core/miner.dart';
import 'balances_page.dart';
import 'dashboard_page.dart';
import 'earnings_page.dart';
import 'log_page.dart';
import 'miner_settings_page.dart';
import 'profit_page.dart';
import 'setup_page.dart';
import 'theme.dart';
import 'wallet_page.dart';
import 'widgets.dart';

int initialPage = 0;

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _i = initialPage.clamp(0, 7);
  static const _items = [
    (Icons.space_dashboard_rounded, 'Panel'),
    (Icons.leaderboard, 'Kârlılık'),
    (Icons.account_balance_wallet, 'Cüzdan ve ödeme'),
    (Icons.savings, 'Bakiyeler'),
    (Icons.tune, 'Madenci ayarları'),
    (Icons.payments, 'Kazanç hesabı'),
    (Icons.checklist, 'Kurulum'),
    (Icons.receipt_long, 'Günlük'),
  ];
  HardwareMonitor? _hw;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hw != null) return;
    final app = AppScope.of(context);
    _hw = app.hardware;
    // Temperature feedback: a coloured notification and a log line whenever a sensor gets warm or too hot.
    _hw!.alerts.addListener(() {
      final a = _hw!.alerts.value;
      if (a == null || !mounted) return;
      app.miner.log('${a.device}: ${a.text}', a.level == TempLevel.hot ? LogKind.error : LogKind.warn);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          Icon(tempLook(a.level).$3, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(child: Text(a.text)),
        ]),
        backgroundColor: a.level == TempLevel.hot ? const Color(0xFF991B1B) : const Color(0xFF92400E),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: a.level == TempLevel.hot ? 10 : 5),
        action: SnackBarAction(label: 'Ayarlar', textColor: Colors.white, onPressed: () => setState(() => _i = 4)),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = AppScope.of(context).miner;
    final hw = AppScope.of(context).hardware;
    void goTo(int v) => setState(() => _i = v);
    final pages = <Widget>[
      DashboardPage(goTo: goTo),
      ProfitPage(goTo: goTo),
      const WalletPage(),
      const BalancesPage(),
      const MinerSettingsPage(),
      const EarningsPage(),
      const SetupPage(),
      const LogPage(),
    ];
    return Scaffold(
      body: Row(children: [
        ListenableBuilder(
          listenable: Listenable.merge([m, hw]),
          builder: (context, _) {
            final look = stateLook(m);
            final extended = MediaQuery.of(context).size.width > 1100;
            return NavigationRail(
              extended: extended,
              minExtendedWidth: 210,
              selectedIndex: _i,
              onDestinationSelected: (v) => setState(() => _i = v),
              leading: BrandHeader(extended: extended),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16, left: 6, right: 6),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      ConstrainedBox(constraints: const BoxConstraints(maxWidth: 190), child: TempChip(label: 'CPU', reading: hw.cpu)),
                      const SizedBox(height: 6),
                      if (hw.gpuName != null) ...[
                        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 190), child: TempChip(label: 'GPU', reading: hw.gpu)),
                        const SizedBox(height: 6),
                      ],
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 190),
                        child: StatusPill(m.busy && m.hashrate > 0 ? humanHash(m.hashrate) : look.$1.split(' ').first, look.$2, icon: look.$3),
                      ),
                      const SizedBox(height: 10),
                      Text(extended ? 'v$appVersion · Jinja Games' : 'v$appVersion', style: const TextStyle(fontSize: 10.5, color: Pal.muted)),
                    ]),
                  ),
                ),
              ),
              destinations: [for (final it in _items) NavigationRailDestination(icon: Icon(it.$1), label: Text(it.$2))],
            );
          },
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: IndexedStack(index: _i, children: pages),
            ),
          ),
        ),
      ]),
    );
  }
}
