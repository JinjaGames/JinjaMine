import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/pool_stats.dart';
import '../core/wallet.dart';
import 'theme.dart';
import 'widgets.dart';

/// Everything mined so far: this app's own estimate, what each pool holds for us, and what was paid out.
class BalancesPage extends StatelessWidget {
  const BalancesPage({super.key});

  static String amount(double v, String coin) => coin == 'XMR' || coin == 'BTC' || coin == 'LTC' ? xmr(v) : v.toStringAsFixed(v >= 100 ? 2 : 4);

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final ps = app.poolStats, s = app.settings, m = app.miner, mk = app.market;
    return ListenableBuilder(
      listenable: Listenable.merge([ps, s, m, mk]),
      builder: (context, _) {
        final entries = ps.entries;
        final price = mk.priceTry ?? 0;
        final allPays = [
          for (final e in entries)
            for (final p in e.payments) (e, p),
        ]..sort((a, b) => b.$2.at.compareTo(a.$2.at));
        return ListView(padding: const EdgeInsets.all(20), children: [
          Section(
            title: 'Özet',
            icon: Icons.account_balance,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (ps.loading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              IconButton(tooltip: 'Tüm bakiyeleri yenile', onPressed: ps.loading ? null : ps.refreshAll, icon: const Icon(Icons.refresh)),
            ]),
            child: StatGrid(minWidth: 180, cards: [
              StatCard(
                label: 'Kazılan (bu uygulamayla)',
                value: '${xmr(s.minedXmrEst)} XMR',
                icon: Icons.construction,
                color: Pal.orange,
                hint: '≈ ${tl(s.minedXmrEst * price)} TL · tahmini, yapılan işten',
              ),
              StatCard(
                label: 'Bu oturumda',
                value: '${xmr(m.sessionXmrEst)} XMR',
                icon: Icons.timer,
                color: Pal.violet,
                hint: '≈ ${tl(m.sessionXmrEst * price)} TL',
              ),
              StatCard(
                label: 'Havuzlarda bekleyen',
                value: '${xmr(ps.totalDueXmr)} XMR',
                icon: Icons.hourglass_bottom,
                color: Pal.amber,
                hint: 'XMR havuzları toplamı · ≈ ${tl(ps.totalDueXmr * price)} TL',
              ),
              StatCard(
                label: 'Cüzdana aktarılan',
                value: '${xmr(ps.totalPaidXmr)} XMR',
                icon: Icons.paid,
                color: Pal.ok,
                hint: '${allPays.length} ödeme · ≈ ${tl(ps.totalPaidXmr * price)} TL',
              ),
            ]),
          ),
          const SizedBox(height: 8),
          const Text(
            '“Kazılan” bu uygulamanın XMRig’e yaptırdığı işin ağ ödülüyle değeridir (havuz ücreti ve XMRig bağışı düşülmüş); havuzun şansına göre gerçek bakiye biraz farklı olur. '
            '“Bekleyen” havuzda biriken, henüz ödenmemiş kısımdır; eşik dolunca cüzdana gönderilir ve “aktarılan”a geçer.',
            style: TextStyle(color: Pal.muted, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            const Section(
              title: 'Henüz bakiye yok',
              icon: Icons.info_outline,
              child: Text('Bir ödeme adresi girip kazmaya başlayınca kullandığın her havuz/adres burada listelenir; sonradan havuz değiştirsen bile eskisi görünmeye devam eder.',
                  style: TextStyle(color: Pal.muted)),
            ),
          for (final e in entries) ...[_EntryCard(e: e, current: e.key == ps.currentKey, price: e.coin == 'XMR' ? price : null), const SizedBox(height: 12)],
          if (allPays.isNotEmpty) ...[
            const SizedBox(height: 4),
            Section(
              title: 'Ödeme geçmişi (cüzdana aktarılanlar)',
              icon: Icons.receipt_long,
              child: Column(children: [
                for (final (e, p) in allPays.take(100))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.call_received, color: Pal.ok, size: 20),
                    title: Text('${amount(p.amount, e.coin)} ${e.coin}', style: const TextStyle(fontFamily: 'Consolas', fontWeight: FontWeight.w700)),
                    subtitle: Text('${_date(p.at)} · ${e.pool.name} → ${shortAddress(e.address)}', style: const TextStyle(color: Pal.muted, fontSize: 12)),
                    trailing: p.url == null
                        ? null
                        : TextButton.icon(
                            onPressed: () => launchUrl(Uri.parse(p.url!), mode: LaunchMode.externalApplication),
                            icon: const Icon(Icons.open_in_new, size: 14),
                            label: const Text('İşlem'),
                          ),
                  ),
              ]),
            ),
          ],
        ]);
      },
    );
  }

  static String _date(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    final l = d.toLocal();
    return '${two(l.day)}.${two(l.month)}.${l.year} ${two(l.hour)}:${two(l.minute)}';
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.e, required this.current, required this.price});
  final BalanceEntry e;
  final bool current;
  final double? price;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).settings;
    final dash = e.pool.dashboard?.replaceAll('{wallet}', e.address).replaceAll('{coin}', e.coin);
    final local = s.walletIsLocal && e.address == s.wallet;
    return Section(
      title: '${e.pool.name} · ${e.coin}',
      icon: Icons.savings,
      trailing: Wrap(spacing: 6, children: [
        if (current) const StatusPill('ŞU AN BURAYA KAZILIYOR', Pal.ok, icon: Icons.bolt),
        if (local) const StatusPill('yerel cüzdan', Pal.violet),
      ]),
      subtitle: e.address,
      child: !e.supported
          ? Row(children: [
              const Expanded(child: Text('Bu havuzun bakiyesi uygulama içinden okunamıyor; web panelinden bak.', style: TextStyle(color: Pal.muted))),
              if (dash != null)
                OutlinedButton.icon(
                    onPressed: () => launchUrl(Uri.parse(dash), mode: LaunchMode.externalApplication), icon: const Icon(Icons.open_in_new, size: 16), label: const Text('Havuz paneli')),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              StatGrid(minWidth: 170, cards: [
                StatCard(
                    label: 'Bekleyen',
                    value: e.due == null ? '—' : BalancesPage.amount(e.due!, e.coin),
                    icon: Icons.hourglass_bottom,
                    color: Pal.amber,
                    hint: price == null || e.due == null ? e.coin : '≈ ${tl(e.due! * price!)} TL'),
                StatCard(
                    label: 'Aktarılan (toplam)',
                    value: e.paid == null ? '—' : BalancesPage.amount(e.paid!, e.coin),
                    icon: Icons.paid,
                    color: Pal.ok,
                    hint: '${e.payments.length} ödeme'),
                StatCard(
                    label: 'Havuzun ölçtüğü hız',
                    value: e.poolHashrate == null ? '—' : humanHash(e.poolHashrate!),
                    icon: Icons.speed,
                    color: Pal.orange,
                    hint: 'birkaç dakika gecikmeli'),
                StatCard(
                    label: 'Son pay',
                    value: e.lastShare == null ? '—' : clock(e.lastShare!),
                    icon: Icons.verified,
                    color: Pal.blue,
                    hint: e.validShares == null ? (e.updatedAt == null ? 'okunuyor…' : 'güncellendi ${clock(e.updatedAt!)}') : 'geçerli ${e.validShares} · geçersiz ${e.invalidShares ?? 0}'),
              ]),
              if (e.error != null) ...[const SizedBox(height: 8), Text(e.error!, style: const TextStyle(color: Pal.muted, fontSize: 12.5))],
              if (dash != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => launchUrl(Uri.parse(dash), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Havuz panelinde aç (ödeme eşiği buradan ayarlanır)'),
                ),
              ],
            ]),
    );
  }
}
