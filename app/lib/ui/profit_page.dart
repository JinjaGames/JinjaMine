import 'package:flutter/material.dart';

import '../core/pools.dart';
import '../core/profit.dart';
import 'theme.dart';
import 'widgets.dart';

/// "Ne kazmalı, nerede?": every option ranked by estimated daily result at this PC's hash rate.
class ProfitPage extends StatefulWidget {
  const ProfitPage({super.key, required this.goTo});
  final ValueChanged<int> goTo;
  @override
  State<ProfitPage> createState() => _ProfitPageState();
}

class _ProfitPageState extends State<ProfitPage> {
  ProfitSort _sort = ProfitSort.net;
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final pr = app.profit, s = app.settings, m = app.miner, mk = app.market;
    return ListenableBuilder(
      listenable: Listenable.merge([pr, s, mk]),
      builder: (context, _) {
        final rec = pr.recommended;
        final cur = pr.optionFor(s.poolId);
        final list = pr.sorted(_sort).where((o) => _all || o.runnable != Runnable.infoOnly).toList();
        final measured = pr.hashrate > 0;
        Future<void> use(ProfitOption o) async {
          if (o.poolId == null) return;
          if (o.runnable == Runnable.needsAddress) {
            s.update(() => s.poolId = o.poolId!);
            snack(context, '${o.where} seçildi. Ödeme adresini gir.');
            widget.goTo(2);
            return;
          }
          s.update(() => s.poolId = o.poolId!);
          app.poolStats.refresh();
          if (m.busy) {
            snack(context, '${o.where} seçildi; madenci yeniden başlatılıyor.');
            await m.restart();
          } else {
            snack(context, '${o.where} seçildi.');
          }
        }

        return ListView(padding: const EdgeInsets.all(20), children: [
          Section(
            title: 'Ne kazmalı, nerede?',
            icon: Icons.leaderboard,
            subtitle: 'Tüm işlemci madenciliği seçenekleri bu bilgisayarın hızıyla (${humanHash(measured ? pr.hashrate : s.manualHashrate)}'
                '${measured ? ', ölçülen' : ', varsayılan — madenci çalışınca ölçülen hız kullanılır'}) karşılaştırılır. '
                'Coinlerin göreli getirisi WhatToMine’dan, XMR ağı xmrchain.net’ten, fiyatlar CoinGecko’dan gelir; gecikme bu bilgisayardan ölçülür. '
                'Fiyat ve zorluk sürekli değiştiği için sıralama 30 dakikada bir kendiliğinden, istersen hemen “Yenile” ile güncellenir.',
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (pr.updatedAt != null) Text('güncellendi ${clock(pr.updatedAt!)}', style: const TextStyle(color: Pal.muted, fontSize: 12)),
              const SizedBox(width: 6),
              FilledButton.icon(
                onPressed: pr.loading
                    ? null
                    : () async {
                        await mk.refresh();
                        await pr.refresh();
                      },
                icon: pr.loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh),
                label: const Text('Yenile'),
              ),
            ]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (pr.error != null) Text(pr.error!, style: const TextStyle(color: Pal.amber, fontSize: 12.5)),
              if (rec != null) _Recommended(rec: rec, current: cur, onUse: () => use(rec)),
              const SizedBox(height: 12),
              Wrap(spacing: 16, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Sırala: ', style: TextStyle(color: Pal.muted)),
                  DropdownButton<ProfitSort>(
                    value: _sort,
                    underline: const SizedBox.shrink(),
                    items: [for (final v in ProfitSort.values) DropdownMenuItem(value: v, child: Text(v.title))],
                    onChanged: (v) => setState(() => _sort = v ?? _sort),
                  ),
                ]),
                FilterChip(label: const Text('Kazılamayanları da göster'), selected: _all, onSelected: (v) => setState(() => _all = v)),
                Tooltip(
                  message: 'Adresi girilmiş seçenekler arasında, biri hem anlık hem 24 saatlik ortalamada en az %5 daha kârlıysa ve bu art arda iki yenilemede '
                      'de böyleyse madenci oraya geçer. Az farkta gidip gelmez.',
                  child: FilterChip(
                    avatar: const Icon(Icons.swap_horiz, size: 16),
                    label: const Text('Otomatik geçiş'),
                    selected: s.autoSwitch,
                    onSelected: (v) => s.update(() => s.autoSwitch = v),
                  ),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(children: [
              const _HeaderRow(),
              if (list.isEmpty)
                const Padding(padding: EdgeInsets.all(24), child: Text('Veri yükleniyor…', style: TextStyle(color: Pal.muted))),
              for (int i = 0; i < list.length; i++)
                _OptionRow(
                  o: list[i],
                  rank: i + 1,
                  isCurrent: list[i].poolId == s.poolId,
                  isRec: rec != null && list[i].id == rec.id,
                  best: list.isEmpty ? 1 : list.map((e) => e.grossTry).reduce((a, b) => a > b ? a : b),
                  onUse: () => use(list[i]),
                ),
            ]),
          ),
          const SizedBox(height: 12),
          const Text(
            'Nasıl okunur: “Brüt” havuz ücreti düşülmüş günlük kazançtır, “Net” bundan elektriği (Kazanç sayfasındaki W ve TL/kWh) çıkarır. '
            'Ödeme süresi, havuzun en düşük ödeme eşiğine ulaşmak için gereken süredir. Likidite, coinin borsalardaki 24 saatlik işlem hacmidir; '
            'çok düşükse (sığ piyasa) kazılan coini fiyatı düşürmeden satmak zordur, bu yüzden öneri yalnızca likit seçenekler arasından yapılır. '
            'XMR dışındaki RandomX coinlerinin her biri kendi havuzunu ve kendi cüzdanını ister; Özel havuz ile denenebilir.',
            style: TextStyle(color: Pal.muted, fontSize: 12, height: 1.45),
          ),
        ]);
      },
    );
  }
}

class _Recommended extends StatelessWidget {
  const _Recommended({required this.rec, required this.current, required this.onUse});
  final ProfitOption rec;
  final ProfitOption? current;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final isCur = current?.id == rec.id;
    final gain = current == null || current!.grossTry <= 0 ? null : rec.grossTry - current!.grossTry;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Pal.orange.withValues(alpha: 0.16), Pal.orange.withValues(alpha: 0.04)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Pal.orange.withValues(alpha: 0.6)),
      ),
      child: Row(children: [
        const Icon(Icons.workspace_premium, color: Pal.orange, size: 34),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Önerilen: ${rec.title} · ${rec.where}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(
              'Günlük ≈ ${tl(rec.grossTry)} TL brüt, ${tl(rec.netTry)} TL net · ücret %${rec.feePct.toStringAsFixed(1)}'
              '${rec.pingMs == null ? '' : ' · ${rec.pingMs} ms'}'
              '${isCur ? ' · şu an bunu kullanıyorsun' : gain != null && gain > 0.005 ? ' · şu ankinden günde +${tl(gain)} TL' : ''}',
              style: const TextStyle(color: Pal.muted, fontSize: 12.5),
            ),
            if (rec.runnable == Runnable.needsAddress)
              const Text('Bunun için ödeme adresi gerekir (Cüzdan ve ödeme sayfası).', style: TextStyle(color: Pal.amber, fontSize: 12.5)),
          ]),
        ),
        if (!isCur) FilledButton.icon(onPressed: onUse, icon: const Icon(Icons.check), label: Text(rec.runnable == Runnable.needsAddress ? 'Seç ve adres gir' : 'Bunu kullan')),
      ]),
    );
  }
}

const _cols = {0: FixedColumnWidth(34), 1: FlexColumnWidth(2.3), 2: FlexColumnWidth(1.25), 3: FlexColumnWidth(1.0), 4: FlexColumnWidth(0.7), 5: FlexColumnWidth(0.95), 6: FlexColumnWidth(0.8), 7: FlexColumnWidth(0.9), 8: FixedColumnWidth(118)};

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();
  @override
  Widget build(BuildContext context) {
    Widget h(String t) => Padding(padding: const EdgeInsets.fromLTRB(6, 12, 6, 10), child: Text(t, style: const TextStyle(color: Pal.muted, fontSize: 12, fontWeight: FontWeight.w700)));
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Pal.line))),
      child: Table(columnWidths: _cols, children: [
        TableRow(children: [h('#'), h('Seçenek'), h('Günlük brüt'), h('Net (elektrik sonrası)'), h('Ücret'), h('Ödeme süresi'), h('Gecikme'), h('Likidite'), h('')]),
      ]),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.o, required this.rank, required this.isCurrent, required this.isRec, required this.best, required this.onUse});
  final ProfitOption o;
  final int rank;
  final bool isCurrent, isRec;
  final double best;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final dim = o.runnable == Runnable.infoOnly;
    final netColor = o.grossTry <= 0 ? Pal.muted : (o.netTry >= 0 ? Pal.ok : Pal.bad);
    Widget cell(Widget c) => Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10), child: c);
    TextStyle mono([Color c = Pal.text]) => TextStyle(fontFamily: 'Consolas', fontSize: 13, color: c);
    final status = switch (o.runnable) {
      Runnable.ready => ('hazır', Pal.ok),
      Runnable.needsAddress => ('adres gerekli', Pal.amber),
      Runnable.advanced => ('ileri düzey', Pal.violet),
      Runnable.infoOnly => ('XMRig kazamaz', Pal.muted),
    };
    return Container(
      decoration: BoxDecoration(
        color: isCurrent ? Pal.orange.withValues(alpha: 0.07) : null,
        border: const Border(bottom: BorderSide(color: Color(0x332A3040))),
      ),
      child: Opacity(
        opacity: dim ? 0.55 : 1,
        child: Table(columnWidths: _cols, defaultVerticalAlignment: TableCellVerticalAlignment.middle, children: [
          TableRow(children: [
            cell(Text('$rank', style: TextStyle(color: isRec ? Pal.orange : Pal.muted, fontWeight: FontWeight.w800))),
            cell(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text('${o.title} · ${o.where}', style: const TextStyle(fontWeight: FontWeight.w700)),
                if (isRec) const StatusPill('ÖNERİLEN', Pal.orange, icon: Icons.star),
                if (isCurrent) const StatusPill('KULLANILIYOR', Pal.blue),
                StatusPill(status.$1, status.$2),
                if (o.thinMarket) const StatusPill('sığ piyasa', Pal.bad, icon: Icons.water_drop_outlined),
                if (o.uncertain) const StatusPill('tahmin belirsiz', Pal.amber, icon: Icons.help_outline),
              ]),
              const SizedBox(height: 3),
              Text('${o.algorithm} · ödeme ${o.payoutCoin} · ${o.note}', style: const TextStyle(color: Pal.muted, fontSize: 11.5)),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: best <= 0 ? 0 : (o.grossTry / best).clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor: Pal.line,
                  color: isRec ? Pal.orange : Pal.blue.withValues(alpha: 0.7),
                ),
              ),
            ])),
            cell(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(o.grossTry <= 0 ? '—' : '${tl(o.grossTry)} TL', style: mono()),
              if (o.grossTry24 > 0 && (o.ratio24 - o.ratio).abs() > 0.02)
                Text('24 sa: ${tl(o.grossTry24)}', style: const TextStyle(color: Pal.muted, fontSize: 11)),
            ])),
            cell(Text(o.grossTry <= 0 ? '—' : '${tl(o.netTry)} TL', style: mono(netColor).copyWith(fontWeight: FontWeight.w700))),
            cell(Text('%${o.feePct.toStringAsFixed(1)}', style: mono())),
            cell(Text(o.payoutDays == null ? '—' : '~${humanDays(o.payoutDays!)}', style: mono())),
            cell(Text(o.pingMs == null ? '—' : '${o.pingMs} ms', style: mono(o.pingMs == null ? Pal.muted : o.pingMs! < 80 ? Pal.ok : o.pingMs! < 160 ? Pal.text : Pal.amber))),
            cell(Text(o.liquidityBtc == null ? '—' : _vol(o.liquidityBtc!), style: mono(o.thinMarket ? Pal.bad : Pal.text))),
            cell(o.poolId == null || isCurrent
                ? const SizedBox.shrink()
                : OutlinedButton(
                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: o.runnable == Runnable.advanced && poolById(o.poolId!).advanced ? null : onUse,
                    child: Text(o.runnable == Runnable.needsAddress ? 'Adres gir' : 'Kullan'),
                  )),
          ]),
        ]),
      ),
    );
  }

  static String _vol(double btc) => btc >= 10 ? '${btc.toStringAsFixed(0)} BTC' : btc >= 0.1 ? '${btc.toStringAsFixed(1)} BTC' : '${(btc * 1000).toStringAsFixed(1)} mBTC';
}
