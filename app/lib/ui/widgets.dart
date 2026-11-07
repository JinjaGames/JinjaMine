import 'package:flutter/material.dart';

import '../core/hardware.dart';
import '../core/market.dart';
import '../core/miner.dart';
import '../core/pool_stats.dart';
import '../core/profit.dart';
import '../core/settings.dart';
import 'theme.dart';

class AppState {
  AppState(this.settings, this.miner, this.market, this.poolStats, this.hardware, this.profit);
  final AppSettings settings;
  final MinerController miner;
  final MarketService market;
  final PoolStatsService poolStats;
  final HardwareMonitor hardware;
  final ProfitService profit;
}

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.state, required super.child});
  final AppState state;
  static AppState of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<AppScope>()!.state;
  @override
  bool updateShouldNotify(AppScope old) => false;
}

// ---------------------------------------------------------------- brand
const appVersion = '2.0.0';

/// "Jinja" in white, "Mine" in orange — the JinjaMine wordmark.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.size = 18});
  final double size;
  @override
  Widget build(BuildContext context) => Text.rich(
        const TextSpan(children: [
          TextSpan(text: 'Jinja', style: TextStyle(color: Pal.text)),
          TextSpan(text: 'Mine', style: TextStyle(color: Pal.orange)),
        ]),
        maxLines: 1,
        style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, letterSpacing: -0.4, height: 1.1),
      );
}

/// App icon with a soft orange glow.
class BrandIcon extends StatelessWidget {
  const BrandIcon({super.key, this.size = 44});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.24),
          boxShadow: [BoxShadow(color: Pal.orange.withValues(alpha: 0.28), blurRadius: size * 0.45, spreadRadius: -size * 0.08)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.22),
          child: Image.asset('assets/icon.png', width: size, height: size, filterQuality: FilterQuality.medium),
        ),
      );
}

/// Top-of-rail brand block: icon + wordmark (+ caption when there is room).
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, required this.extended});
  final bool extended;
  @override
  Widget build(BuildContext context) {
    if (!extended) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(8, 18, 8, 14),
        child: Column(children: [BrandIcon(size: 44), SizedBox(height: 8), BrandWordmark(size: 12.5)]),
      );
    }
    return const Padding(
      padding: EdgeInsets.fromLTRB(14, 20, 14, 16),
      child: SizedBox(
        width: 182,
        child: Row(children: [
          BrandIcon(size: 42),
          SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              BrandWordmark(size: 19),
              SizedBox(height: 3),
              Text('Kripto madencilik', style: TextStyle(fontSize: 11.5, color: Pal.muted)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Dashboard hero: big wordmark, current route and live status over a warm gradient with the logo as a watermark.
class BrandHero extends StatelessWidget {
  const BrandHero({super.key, required this.status, required this.statusColor, required this.route, required this.headline});
  final String status;
  final Color statusColor;
  final String route;
  final String headline;
  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Pal.line),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF241509), Pal.surface, Pal.surface],
          stops: [0, 0.55, 1],
        ),
      ),
      child: Stack(children: [
        Positioned(
          right: -36,
          top: -40,
          child: Opacity(opacity: 0.10, child: Image.asset('assets/logo_mark.png', width: 230, height: 230)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
          child: Row(children: [
            const BrandIcon(size: 64),
            const SizedBox(width: 18),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const BrandWordmark(size: 28),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Pal.surface2, borderRadius: BorderRadius.circular(6), border: Border.all(color: Pal.line)),
                    child: const Text('v$appVersion', style: TextStyle(fontSize: 11, color: Pal.muted)),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(headline, style: const TextStyle(fontSize: 13.5, color: Pal.muted)),
                const SizedBox(height: 10),
                Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(status, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: statusColor)),
                  ]),
                  const Text('·', style: TextStyle(color: Pal.muted)),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.alt_route, size: 15, color: Pal.muted),
                    const SizedBox(width: 5),
                    Text(route, style: const TextStyle(fontSize: 13, color: Pal.text)),
                  ]),
                ]),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

class Section extends StatelessWidget {
  const Section({super.key, required this.title, required this.child, this.trailing, this.icon, this.subtitle});
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (icon != null) ...[Icon(icon, size: 18, color: Pal.orange), const SizedBox(width: 8)],
            Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
            ?trailing,
          ]),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: const TextStyle(color: Pal.muted, fontSize: 12.5, height: 1.35)),
          ],
          const SizedBox(height: 12),
          child,
        ]),
      ),
    );
  }
}

/// Equal-sized stat tile.
class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.label, required this.value, this.icon, this.color = Pal.orange, this.hint, this.width = 200});
  static const double height = 98;
  final String label, value;
  final String? hint;
  final IconData? icon;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: Pal.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: Pal.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (icon != null) ...[Icon(icon, size: 15, color: color), const SizedBox(width: 6)],
          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Pal.muted, fontSize: 12))),
        ]),
        const Spacer(),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
        ),
        const SizedBox(height: 2),
        Text(hint ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Pal.muted, fontSize: 11)),
      ]),
    );
  }
}

/// Balanced rows of equal-width tiles (8 tiles -> 2 rows of 4).
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.cards, this.minWidth = 190, this.gap = 12});
  final List<StatCard> cards;
  final double minWidth, gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final n = cards.length;
      final maxCols = ((c.maxWidth + gap) / (minWidth + gap)).floor().clamp(1, n);
      final rows = (n / maxCols).ceil();
      final cols = (n / rows).ceil();
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(spacing: gap, runSpacing: gap, children: [
        for (final k in cards) StatCard(label: k.label, value: k.value, icon: k.icon, color: k.color, hint: k.hint, width: w),
      ]);
    });
  }
}

class SliderTile extends StatelessWidget {
  const SliderTile({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.display,
    this.help,
  });
  final String label;
  final double value, min, max;
  final int? divisions;
  final String? display, help;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Text(display ?? value.toStringAsFixed(1), style: const TextStyle(color: Pal.orange, fontWeight: FontWeight.w700)),
        ]),
        Slider(value: value.clamp(min, max), min: min, max: max, divisions: divisions, onChanged: onChanged),
        if (help != null) Text(help!, style: const TextStyle(color: Pal.muted, fontSize: 12, height: 1.35)),
      ]),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.text, this.color, {super.key, this.icon});
  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.5))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 5)],
        Flexible(child: Text(text, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

/// Check-list row: green tick or grey circle plus text.
class CheckRow extends StatelessWidget {
  const CheckRow(this.ok, this.text, {super.key, this.detail, this.warn = false});
  final bool ok, warn;
  final String text;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final c = ok ? Pal.ok : warn ? Pal.amber : Pal.muted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(ok ? Icons.check_circle : warn ? Icons.error_outline : Icons.radio_button_unchecked, size: 18, color: c),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (detail != null) Text(detail!, style: const TextStyle(color: Pal.muted, fontSize: 12, height: 1.35)),
          ]),
        ),
      ]),
    );
  }
}

(String, Color, IconData) stateLook(MinerController m) => switch (m.state) {
      MinerState.running => ('KAZIYOR', Pal.ok, Icons.bolt),
      MinerState.starting => ('BAŞLIYOR', Pal.amber, Icons.hourglass_top),
      MinerState.paused => ('DURAKLADI${m.pauseReason == null ? '' : ' · ${m.pauseReason}'}', Pal.blue, Icons.pause_circle),
      MinerState.error => ('HATA', Pal.bad, Icons.error),
      MinerState.stopped => ('DURDU', Pal.muted, Icons.stop_circle),
    };

void snack(BuildContext c, String msg, {bool error = false}) {
  ScaffoldMessenger.of(c).showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: error ? const Color(0xFF7F1D1D) : Pal.surface2,
    behavior: SnackBarBehavior.floating,
    duration: Duration(seconds: error ? 6 : 3),
  ));
}

// ---------------------------------------------------------------- temperature feedback
/// Colour, word, icon and advice for a temperature level.
(Color, String, IconData) tempLook(TempLevel l) => switch (l) {
      TempLevel.cool => (Pal.blue, 'serin', Icons.ac_unit),
      TempLevel.normal => (Pal.ok, 'normal', Icons.thermostat),
      TempLevel.warm => (Pal.amber, 'sıcak', Icons.warning_amber_rounded),
      TempLevel.hot => (Pal.bad, 'çok sıcak', Icons.local_fire_department),
      TempLevel.unknown => (Pal.muted, 'okunamıyor', Icons.device_thermostat),
    };

/// Small chip: "İşlemci 72 °C" coloured by level; pulses when too hot.
class TempChip extends StatelessWidget {
  const TempChip({super.key, required this.label, required this.reading});
  final String label;
  final TempReading reading;

  @override
  Widget build(BuildContext context) {
    final look = tempLook(reading.level);
    final chip = Tooltip(
      message: '${reading.source} · ${look.$2}',
      child: StatusPill(reading.celsius == null ? '$label —' : '$label ${reading.celsius!.toStringAsFixed(0)} °C', look.$1, icon: look.$3),
    );
    return reading.level == TempLevel.hot ? Pulse(color: Pal.bad, child: chip) : chip;
  }
}

/// Large gauge: value, coloured scale with the user's limit marked, level word and a one-line advice.
class TempGauge extends StatelessWidget {
  const TempGauge({super.key, required this.title, required this.reading, required this.limit, this.extra, this.missing});
  final String title;
  final TempReading reading;
  final int limit;
  final String? extra, missing;

  String get _advice => switch (reading.level) {
        TempLevel.cool => 'Rahat çalışıyor; soğutma yeterli.',
        TempLevel.normal => 'Yük altında olağan sıcaklık.',
        TempLevel.warm => 'Sınıra yaklaşıyor. Toz, fan eğrisi ve kasa hava akışını kontrol et.',
        TempLevel.hot => 'Sınırın üstünde! Koruma açıksa yük otomatik azaltılır.',
        TempLevel.unknown => missing ?? 'Sensör okunamıyor.',
      };

  @override
  Widget build(BuildContext context) {
    final look = tempLook(reading.level);
    final t = reading.celsius;
    const lo = 30.0, hi = 100.0;
    double frac(double v) => ((v - lo) / (hi - lo)).clamp(0.0, 1.0);
    final box = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: look.$1.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: look.$1.withValues(alpha: reading.level == TempLevel.unknown ? 0.25 : 0.6)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(look.$3, color: look.$1, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
          StatusPill(look.$2.toUpperCase(), look.$1),
        ]),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(t == null ? '—' : t.toStringAsFixed(0), style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: look.$1, height: 1)),
          Padding(padding: const EdgeInsets.only(bottom: 3, left: 2), child: Text('°C', style: TextStyle(color: look.$1, fontWeight: FontWeight.w700))),
          const Spacer(),
          if (extra != null) Flexible(child: Text(extra!, textAlign: TextAlign.right, style: const TextStyle(color: Pal.muted, fontSize: 11.5, height: 1.3))),
        ]),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth;
          return SizedBox(
            height: 22,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned(
                left: 0,
                right: 0,
                top: 6,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: LinearGradient(colors: const [Pal.blue, Pal.ok, Pal.ok, Pal.amber, Pal.bad], stops: [
                      0,
                      frac(50),
                      frac(limit - 10.0),
                      frac(limit - 10.0) + 0.001,
                      frac(limit.toDouble()),
                    ]),
                  ),
                ),
              ),
              Positioned(left: frac(limit.toDouble()) * w - 1, top: 2, child: Container(width: 2, height: 16, color: Pal.text.withValues(alpha: 0.7))),
              if (t != null)
                Positioned(
                  left: (frac(t) * w - 7).clamp(0.0, w - 14),
                  top: 3,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(color: look.$1, shape: BoxShape.circle, border: Border.all(color: Pal.bg, width: 2)),
                  ),
                ),
            ]),
          );
        }),
        Row(children: [
          const Text('30', style: TextStyle(color: Pal.muted, fontSize: 10)),
          const Spacer(),
          Text('sınır $limit °C', style: const TextStyle(color: Pal.muted, fontSize: 10)),
          const Spacer(),
          const Text('100', style: TextStyle(color: Pal.muted, fontSize: 10)),
        ]),
        const SizedBox(height: 6),
        Text(_advice, style: TextStyle(color: reading.level == TempLevel.unknown ? Pal.muted : look.$1, fontSize: 12, height: 1.35)),
        Text('Kaynak: ${reading.source}', style: const TextStyle(color: Pal.muted, fontSize: 10.5)),
      ]),
    );
    return reading.level == TempLevel.hot ? Pulse(color: Pal.bad, radius: 14, child: box) : box;
  }
}

/// Soft pulsing glow used for critical states.
class Pulse extends StatefulWidget {
  const Pulse({super.key, required this.child, required this.color, this.radius = 20});
  final Widget child;
  final Color color;
  final double radius;
  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (context, child) => DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: [BoxShadow(color: widget.color.withValues(alpha: 0.15 + 0.35 * _c.value), blurRadius: 6 + 10 * _c.value)],
          ),
          child: child,
        ),
      );
}
