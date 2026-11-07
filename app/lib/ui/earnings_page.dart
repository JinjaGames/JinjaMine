import 'package:flutter/material.dart';

import '../core/market.dart';
import '../core/pools.dart';
import 'theme.dart';
import 'widgets.dart';

class EarningsPage extends StatefulWidget {
  const EarningsPage({super.key});
  @override
  State<EarningsPage> createState() => _EarningsPageState();
}

class _EarningsPageState extends State<EarningsPage> {
  late final TextEditingController _kwh, _watts, _hash;
  bool _inited = false;
  bool _useMeasured = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;
    _inited = true;
    final s = AppScope.of(context).settings;
    _kwh = TextEditingController(text: s.electricityTlPerKwh.toString());
    _watts = TextEditingController(text: s.extraWatts.toStringAsFixed(0));
    _hash = TextEditingController(text: s.manualHashrate.toStringAsFixed(0));
  }

  double? _num(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.').trim());

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.settings, m = app.miner, mk = app.market;
    return ListenableBuilder(
      listenable: Listenable.merge([s, m, mk]),
      builder: (context, _) {
        final measured = (m.summary?.hr15m ?? 0) > 0 ? m.summary!.hr15m! : (m.summary?.hr60s ?? 0);
        final hr = _useMeasured && measured > 0 ? measured : s.manualHashrate;
        final pool = poolById(s.poolId);
        Earnings? e(double d) => Earnings.compute(m: mk, hashrate: hr, days: d, poolFeePct: pool.feePct, watts: s.extraWatts, tlPerKwh: s.electricityTlPerKwh);
        final perDay = mk.xmrPerDay(hr);
        final payoutDays = perDay == null || perDay <= 0 || pool.minPayout <= 0 ? null : pool.minPayout / (perDay * (1 - pool.feePct / 100));
        final rows = [('Günlük', 1.0), ('Haftalık', 7.0), ('Aylık', 30.0), ('Yıllık', 365.0)];
        final breakEvenKwh = perDay == null || mk.priceTry == null || s.extraWatts <= 0 ? null : perDay * (1 - pool.feePct / 100) * mk.priceTry! / (s.extraWatts / 1000 * 24);
        return ListView(padding: const EdgeInsets.all(20), children: [
          Section(
            title: 'Hesap girdileri',
            icon: Icons.calculate,
            subtitle: 'Elektrik birim fiyatını faturandan al (vergiler dahil TL/kWh). “Ek güç”, kazarken bilgisayarın boştakine göre fazladan çektiği güçtür; 7950X tüm çekirdeklerle RandomX’te ~120–170 W fazladan çeker.',
            child: Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
              SizedBox(width: 200, child: TextField(controller: _kwh, decoration: const InputDecoration(labelText: 'Elektrik (TL/kWh)'))),
              SizedBox(width: 200, child: TextField(controller: _watts, decoration: const InputDecoration(labelText: 'Ek güç (W)'))),
              SizedBox(width: 220, child: TextField(controller: _hash, decoration: const InputDecoration(labelText: 'Varsayılan hız (H/s)'))),
              FilledButton(
                onPressed: () {
                  final k = _num(_kwh), w = _num(_watts), h = _num(_hash);
                  if (k == null || w == null || h == null || k < 0 || w < 0 || h <= 0) return snack(context, 'Sayıları kontrol et.', error: true);
                  s.update(() {
                    s.electricityTlPerKwh = k;
                    s.extraWatts = w;
                    s.manualHashrate = h;
                  });
                  snack(context, 'Hesap güncellendi.');
                },
                child: const Text('Hesapla'),
              ),
              FilterChip(
                label: Text(measured > 0 ? 'Ölçülen hızı kullan (${humanHash(measured)})' : 'Ölçülen hız yok (madenci çalışmıyor)'),
                selected: _useMeasured && measured > 0,
                onSelected: measured > 0 ? (v) => setState(() => _useMeasured = v) : null,
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Section(
            title: 'Tahmini kazanç — ${humanHash(hr)}, ${pool.name} (%${pool.feePct.toStringAsFixed(1)} ücret)',
            icon: Icons.payments,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (mk.updatedAt != null) Text('veri ${clock(mk.updatedAt!)}', style: const TextStyle(color: Pal.muted, fontSize: 12)),
              IconButton(tooltip: 'Ağ ve fiyatı yenile', onPressed: mk.loading ? null : mk.refresh, icon: const Icon(Icons.refresh)),
            ]),
            child: e(1) == null
                ? Text(mk.loading ? 'Ağ verisi yükleniyor…' : 'Ağ verisi alınamadı: ${mk.error ?? ''}', style: const TextStyle(color: Pal.muted))
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Table(
                      columnWidths: const {0: FlexColumnWidth(1.1), 1: FlexColumnWidth(1.3), 2: FlexColumnWidth(1.2), 3: FlexColumnWidth(1.2), 4: FlexColumnWidth(1.2), 5: FlexColumnWidth(1)},
                      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                      children: [
                        _row(['Dönem', 'XMR', 'Brüt TL', 'Elektrik TL', 'Net TL', 'Brüt \$'], header: true),
                        for (final r in rows)
                          () {
                            final x = e(r.$2)!;
                            return _row([r.$1, xmr(x.xmr), tl(x.grossTry), tl(x.powerTry), tl(x.netTry), x.grossUsd.toStringAsFixed(2)], net: x.netTry);
                          }(),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(spacing: 18, runSpacing: 8, children: [
                      _fact('Havuz ödeme eşiğine', payoutDays == null ? '—' : '~${humanDays(payoutDays)} (${pool.minPayout} XMR)'),
                      _fact('Başa baş elektrik fiyatı', breakEvenKwh == null ? '—' : '${tl(breakEvenKwh)} TL/kWh'),
                      _fact('Ağdaki payın', mk.networkHashrate == null ? '—' : '1 / ${tl(mk.networkHashrate! / hr, digits: 0)}'),
                      _fact('Tek başına (solo) blok bulma', mk.soloDays(hr) == null ? '—' : 'ortalama ${humanDays(mk.soloDays(hr)!)}'),
                    ]),
                    const SizedBox(height: 10),
                    const Text(
                      'Bu bir beklenen değerdir: havuz şansı, ağ zorluğu ve XMR fiyatı her gün değişir. Kazanç XMR olarak gelir; TL karşılığı, sattığın günün fiyatına bağlıdır. '
                      'Donanım yıpranması ve ısı burada hesaba katılmaz.',
                      style: TextStyle(color: Pal.muted, fontSize: 12, height: 1.4),
                    ),
                  ]),
          ),
          const SizedBox(height: 16),
          Section(
            title: 'Monero ağı (canlı)',
            icon: Icons.public,
            child: StatGrid(minWidth: 170, cards: [
              StatCard(label: 'Ağ hash hızı', value: mk.networkHashrate == null ? '—' : humanHash(mk.networkHashrate!), icon: Icons.public, color: Pal.blue, hint: 'tüm dünya'),
              StatCard(label: 'Zorluk', value: mk.difficulty == null ? '—' : '${(mk.difficulty! / 1e9).toStringAsFixed(1)} G', icon: Icons.trending_up, color: Pal.violet, hint: 'blok ${mk.height ?? '—'}'),
              StatCard(label: 'Blok ödülü', value: mk.blockReward == null ? '—' : '${mk.blockReward!.toStringAsFixed(4)} XMR', icon: Icons.token, color: Pal.orange, hint: '2 dakikada bir blok'),
              StatCard(label: 'XMR', value: mk.priceTry == null ? '—' : '${tl(mk.priceTry!, digits: 0)} TL', icon: Icons.currency_exchange, color: Pal.ok,
                  hint: mk.priceUsd == null ? 'CoinGecko' : '${mk.priceUsd!.toStringAsFixed(2)} \$ · CoinGecko'),
            ]),
          ),
        ]);
      },
    );
  }

  TableRow _row(List<String> cells, {bool header = false, double? net}) => TableRow(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Pal.line.withValues(alpha: header ? 1 : 0.5)))),
        children: [
          for (int i = 0; i < cells.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Text(cells[i],
                  style: TextStyle(
                    fontSize: header ? 12 : 13.5,
                    color: header ? Pal.muted : (i == 4 && net != null ? (net >= 0 ? Pal.ok : Pal.bad) : Pal.text),
                    fontWeight: header || i == 4 ? FontWeight.w700 : FontWeight.w400,
                    fontFamily: !header && i > 0 ? 'Consolas' : null,
                  )),
            ),
        ],
      );

  Widget _fact(String k, String v) => RichText(
        text: TextSpan(style: const TextStyle(fontSize: 13, fontFamily: 'Segoe UI'), children: [
          TextSpan(text: '$k: ', style: const TextStyle(color: Pal.muted)),
          TextSpan(text: v, style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w600)),
        ]),
      );
}
