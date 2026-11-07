import 'dart:math';

import 'package:flutter/material.dart';

import '../core/market.dart';
import '../core/miner.dart';
import '../core/pools.dart';
import '../core/settings.dart';
import '../core/wallet.dart';
import 'theme.dart';
import 'widgets.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.goTo});
  final ValueChanged<int> goTo;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final m = app.miner, s = app.settings, mk = app.market, ps = app.poolStats, hw = app.hardware, pr = app.profit;
    return ListenableBuilder(
      listenable: Listenable.merge([m, s, mk, ps, hw, pr]),
      builder: (context, _) {
        final sum = m.summary;
        final look = stateLook(m);
        final hr = m.busy && m.hashrate > 0 ? m.hashrate : s.manualHashrate;
        final day = Earnings.compute(m: mk, hashrate: hr, days: 1, poolFeePct: poolById(s.poolId).feePct, watts: s.extraWatts, tlPerKwh: s.electricityTlPerKwh);
        final hp = sum?.hugePages;
        final problems = m.problems();
        final pool = poolById(s.poolId);
        return ListView(padding: const EdgeInsets.all(20), children: [
          BrandHero(
            status: m.busy && m.hashrate > 0 ? '${look.$1.split(' ').first} · ${humanHash(m.hashrate)}' : look.$1,
            statusColor: look.$2,
            route: '${pool.name} → ${s.payoutCoinOf()}',
            headline: day != null && day.grossTry > 0
                ? 'Bu hızla günde ~${tl(day.grossTry)} TL brüt, ~${tl(day.netTry)} TL net · Monero / RandomX işlemci madenciliği'
                : 'Monero / RandomX işlemci madenciliği · XMRig ön yüzü',
          ),
          const SizedBox(height: 16),
          // ---------------------------------------------------------------- control bar
          Section(
            title: 'Madencilik',
            icon: Icons.bolt,
            trailing: StatusPill(look.$1, look.$2, icon: look.$3),
            child: Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: m.busy ? Pal.bad : Pal.orange,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                  ),
                  onPressed: () async {
                    if (m.busy) {
                      await m.stop();
                    } else {
                      final p = m.problems();
                      if (p.isNotEmpty) {
                        snack(context, p.first, error: true);
                        goTo(p.first.startsWith('xmrig') ? 6 : 2);
                        return;
                      }
                      await m.start();
                    }
                  },
                  icon: Icon(m.busy ? Icons.stop_circle : Icons.play_circle_fill, size: 26),
                  label: Text(m.busy ? 'Durdur' : 'Kazmaya başla', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ),
              ),
              if (m.state == MinerState.running)
                OutlinedButton.icon(onPressed: () => m.pause('elle'), icon: const Icon(Icons.pause), label: const Text('Duraklat')),
              if (m.state == MinerState.paused)
                OutlinedButton.icon(onPressed: m.resume, icon: const Icon(Icons.play_arrow), label: const Text('Devam et')),
              if (m.busy)
                OutlinedButton.icon(onPressed: m.restart, icon: const Icon(Icons.restart_alt), label: const Text('Yeniden başlat')),
              if (m.startedAt != null && m.busy)
                Text('Oturum: ${humanDuration(DateTime.now().difference(m.startedAt!).inSeconds)} · ${s.mode.title}',
                    style: const TextStyle(color: Pal.muted, fontSize: 12.5)),
            ]),
          ),
          if (problems.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Pal.amber.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: Pal.amber.withValues(alpha: 0.5))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Başlamadan önce tamamlanacaklar', style: TextStyle(fontWeight: FontWeight.w700, color: Pal.amber)),
                const SizedBox(height: 6),
                for (final p in problems) Text('• $p', style: const TextStyle(fontSize: 13, height: 1.4)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  OutlinedButton(onPressed: () => goTo(2), child: const Text('Cüzdan ve ödeme')),
                  OutlinedButton(onPressed: () => goTo(6), child: const Text('Kurulum')),
                ]),
              ]),
            ),
          ],
          if (pr.recommended != null && pr.recommended!.poolId != s.poolId && (pr.optionFor(s.poolId)?.grossTry ?? 0) > 0 &&
              pr.recommended!.grossTry > pr.optionFor(s.poolId)!.grossTry * 1.02) ...[
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => goTo(1),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Pal.orange.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: Pal.orange.withValues(alpha: 0.5))),
                child: Row(children: [
                  const Icon(Icons.trending_up, color: Pal.orange),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                        'Daha kârlı bir seçenek var: ${pr.recommended!.title} · ${pr.recommended!.where} — günde ≈ +${tl(pr.recommended!.grossTry - pr.optionFor(s.poolId)!.grossTry)} TL. '
                        'Kârlılık sayfasında karşılaştır.'),
                  ),
                  const Icon(Icons.chevron_right, color: Pal.muted),
                ]),
              ),
            ),
          ],
          const SizedBox(height: 16),
          // ---------------------------------------------------------------- numbers
          StatGrid(cards: [
            StatCard(label: 'Hash hızı (10 sn)', value: m.busy ? humanHash(sum?.hr10s ?? 0) : '—', icon: Icons.speed, color: Pal.orange,
                hint: sum == null ? 'madenci çalışmıyor' : '60 sn ${humanHash(sum.hr60s ?? 0)} · 15 dk ${humanHash(sum.hr15m ?? 0)}'),
            StatCard(label: 'Kabul edilen pay', value: sum == null ? '—' : '${sum.accepted}', icon: Icons.verified, color: Pal.ok,
                hint: sum == null ? 'havuzun onayladığı işler' : 'red ${sum.rejected} · zorluk ${sum.diff}'),
            StatCard(label: 'Havuz', value: poolById(s.poolId).name.split(' (').first, icon: Icons.hub, color: Pal.blue,
                hint: sum == null
                    ? (s.payoutAddress().isEmpty ? 'ödeme adresi yok' : '${s.payoutCoinOf()} → ${shortAddress(s.payoutAddress())}${s.walletIsLocal && s.poolId != 'unmineable' && s.poolId != 'nicehash' ? ' (yerel)' : ''}')
                    : '${sum.pool} · ${sum.ping} ms'),
            StatCard(label: 'İş parçacığı', value: m.busy ? '${m.currentThreads}' : '${s.threads}', icon: Icons.memory, color: m.thermalCap != null ? Pal.bad : Pal.violet,
                hint: m.thermalCap != null
                    ? 'sıcaklık nedeniyle en çok ${m.thermalCap}'
                    : m.tune != null && !m.tune!.done
                        ? 'otomatik ayar sürüyor'
                        : m.activeGame != null
                            ? 'oyun algılandı: ${m.activeGame}'
                            : 'boşta ${humanDuration(m.idleSec)}'),
            StatCard(
                label: 'Tahmini günlük (net)',
                value: day == null ? '—' : '${tl(day.netTry)} TL',
                icon: Icons.payments,
                color: day == null || day.netTry >= 0 ? Pal.ok : Pal.bad,
                hint: day == null ? 'ağ verisi bekleniyor' : '${xmr(day.xmr)} XMR · elektrik ${tl(day.powerTry)} TL'),
            StatCard(
                label: 'Havuzda bekleyen',
                value: ps.due == null ? '—' : '${ps.coin == 'XMR' ? xmr(ps.due!) : ps.due!.toStringAsFixed(4)} ${ps.coin}',
                icon: Icons.savings,
                color: Pal.amber,
                hint: ps.due == null
                    ? (s.payoutAddress().isEmpty ? 'ödeme adresi girilince okunur' : (ps.current?.supported == false ? 'bu havuz için web panelini kullan' : 'okunuyor…'))
                    : 'aktarılan ${ps.coin == 'XMR' ? xmr(ps.paid ?? 0) : (ps.paid ?? 0).toStringAsFixed(4)} ${ps.coin}'),
            StatCard(
                label: 'Huge pages',
                value: hp == null ? '—' : '${hp[1] == 0 ? 0 : (hp[0] * 100 / hp[1]).round()} %',
                icon: Icons.memory_outlined,
                color: hp != null && hp[1] > 0 && hp[0] == hp[1] ? Pal.ok : Pal.amber,
                hint: hp == null ? 'çalışınca görünür' : '${hp[0]}/${hp[1]} sayfa · MSR ${sum!.msr ? 'açık' : 'kapalı'}'),
            StatCard(label: 'XMR fiyatı', value: mk.priceTry == null ? '—' : '${tl(mk.priceTry!, digits: 0)} TL', icon: Icons.currency_exchange, color: Pal.text,
                hint: mk.priceUsd == null ? (mk.error ?? 'yükleniyor') : '${mk.priceUsd!.toStringAsFixed(2)} \$'),
          ]),
          const SizedBox(height: 16),
          Section(
            title: 'Donanım sıcaklığı',
            icon: Icons.device_thermostat,
            subtitle: s.tempGuard
                ? 'Koruma açık: işlemci ${s.cpuTempLimit} °C’yi 20 sn aşarsa iş parçacığı %25 azaltılır, serinleyince geri artırılır (Madenci ayarları).'
                : 'Koruma kapalı (Madenci ayarları → Sıcaklık koruması).',
            child: LayoutBuilder(builder: (context, c) {
              final cpu = TempGauge(
                title: 'İşlemci (CPU)',
                reading: hw.cpu,
                limit: s.cpuTempLimit,
                extra: m.busy ? '${m.currentThreads} iş parçacığı${m.thermalCap != null ? '\nkoruma: en çok ${m.thermalCap}' : ''}' : null,
                missing: 'Ryzen sıcaklığını Windows sürücüsüz vermez. LibreHardwareMonitor’ı (ücretsiz) yönetici olarak açık tutarsan burada görünür; Kurulum sayfasında bağlantı var.',
              );
              final gpu = TempGauge(
                title: hw.gpuName ?? 'Ekran kartı (GPU)',
                reading: hw.gpu,
                limit: s.gpuTempLimit,
                extra: hw.gpuTemp == null ? null : 'yük %${hw.gpuLoad?.toStringAsFixed(0) ?? '—'} · ${hw.gpuPower?.toStringAsFixed(0) ?? '—'} W\nfan %${hw.gpuFan?.toStringAsFixed(0) ?? '—'}',
                missing: hw.gpuError,
              );
              return c.maxWidth > 760
                  ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: cpu), const SizedBox(width: 12), Expanded(child: gpu)])
                  : Column(children: [cpu, const SizedBox(height: 12), gpu]);
            }),
          ),
          const SizedBox(height: 16),
          _ChartCard(m: m),
          const SizedBox(height: 16),
          Section(
            title: 'Bilgi',
            icon: Icons.info_outline,
            child: Text(
              sum == null
                  ? 'Madenci çalışınca XMRig sürümü, işlemci ve havuz bağlantısı burada görünür. Tahmini kazanç, çalışmazken Kazanç sayfasındaki “varsayılan hız” (${humanHash(s.manualHashrate)}) ile hesaplanır.'
                  : 'XMRig ${sum.version} · ${sum.cpuBrand} · algoritma ${sum.algo} · bağış %${sum.donate} · havuz bağlantısı ${humanDuration(sum.poolUptime)} · '
                      'toplam ${humanHash(sum.hashesTotal.toDouble()).replaceAll('/s', '')} hash · en yüksek ${humanHash(sum.highest ?? 0)}',
              style: const TextStyle(color: Pal.muted, fontSize: 12.5, height: 1.4),
            ),
          ),
        ]);
      },
    );
  }
}

class _ChartCard extends StatefulWidget {
  const _ChartCard({required this.m});
  final MinerController m;
  @override
  State<_ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<_ChartCard> {
  int _minutes = 30;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final pts = widget.m.history.where((e) => now.difference(e.$1).inMinutes < _minutes).toList();
    return Section(
      title: 'Hash hızı geçmişi',
      icon: Icons.show_chart,
      trailing: SegmentedButton<int>(
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
        segments: const [
          ButtonSegment(value: 30, label: Text('30 dk')),
          ButtonSegment(value: 360, label: Text('6 sa')),
          ButtonSegment(value: 1440, label: Text('24 sa')),
        ],
        selected: {_minutes},
        onSelectionChanged: (v) => setState(() => _minutes = v.first),
      ),
      child: SizedBox(
        height: 190,
        child: pts.length < 2
            ? const Center(child: Text('Madenci çalıştıkça 10 saniyede bir nokta eklenir.', style: TextStyle(color: Pal.muted)))
            : CustomPaint(painter: _ChartPainter(pts, Duration(minutes: _minutes)), size: Size.infinite),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.pts, this.span);
  final List<(DateTime, double)> pts;
  final Duration span;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 64.0, bottom = 20.0;
    final w = size.width - left, h = size.height - bottom;
    final maxV = max(1.0, pts.map((e) => e.$2).reduce(max)) * 1.15;
    final end = pts.last.$1;
    final start = end.subtract(span);
    final grid = Paint()
      ..color = Pal.line
      ..strokeWidth = 1;
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i <= 4; i++) {
      final y = h - h * i / 4;
      canvas.drawLine(Offset(left, y), Offset(size.width, y), grid);
      tp.text = TextSpan(text: humanHash(maxV * i / 4), style: const TextStyle(color: Pal.muted, fontSize: 10.5));
      tp.layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }
    double x(DateTime t) => left + w * (t.difference(start).inMilliseconds / span.inMilliseconds).clamp(0.0, 1.0);
    double y(double v) => h - h * (v / maxV);
    final path = Path()..moveTo(x(pts.first.$1), y(pts.first.$2));
    for (final p in pts.skip(1)) {
      path.lineTo(x(p.$1), y(p.$2));
    }
    final fill = Path.from(path)
      ..lineTo(x(pts.last.$1), h)
      ..lineTo(x(pts.first.$1), h)
      ..close();
    canvas.drawPath(
        fill,
        Paint()
          ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x55FF7A1A), Color(0x00FF7A1A)])
              .createShader(Rect.fromLTWH(0, 0, size.width, h)));
    canvas.drawPath(
        path,
        Paint()
          ..color = Pal.orange
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke);
    tp.text = TextSpan(text: '${clock(start)}  →  ${clock(end)}', style: const TextStyle(color: Pal.muted, fontSize: 10.5));
    tp.layout();
    tp.paint(canvas, Offset(left, h + 4));
  }

  @override
  bool shouldRepaint(_ChartPainter old) => true;
}
