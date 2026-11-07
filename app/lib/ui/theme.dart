import 'package:flutter/material.dart';

class Pal {
  static const bg = Color(0xFF0B0D12);
  static const surface = Color(0xFF13161E);
  static const surface2 = Color(0xFF1B1F2A);
  static const line = Color(0xFF2A3040);
  static const orange = Color(0xFFFF7A1A); // Monero orange
  static const amber = Color(0xFFF5B942);
  static const ok = Color(0xFF34D399);
  static const bad = Color(0xFFF87171);
  static const blue = Color(0xFF60A5FA);
  static const violet = Color(0xFFA78BFA);
  static const text = Color(0xFFE8ECF4);
  static const muted = Color(0xFF8E98AD);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: Pal.orange, brightness: Brightness.dark).copyWith(
    primary: Pal.orange,
    onPrimary: Colors.black,
    secondary: Pal.amber,
    surface: Pal.surface,
    error: Pal.bad,
    onSurface: Pal.text,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Pal.bg,
    fontFamily: 'Segoe UI',
    cardTheme: CardThemeData(
      color: Pal.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Pal.line)),
    ),
    dividerColor: Pal.line,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Pal.surface2,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Pal.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Pal.line)),
      isDense: true,
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Pal.surface,
      indicatorColor: Color(0x33FF7A1A),
      selectedIconTheme: IconThemeData(color: Pal.orange),
      unselectedIconTheme: IconThemeData(color: Pal.muted),
      selectedLabelTextStyle: TextStyle(color: Pal.orange, fontWeight: FontWeight.w600),
      unselectedLabelTextStyle: TextStyle(color: Pal.muted),
    ),
    sliderTheme: const SliderThemeData(trackHeight: 3),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    ),
  );
}

String humanHash(double h) {
  if (h.isNaN || h <= 0) return '0 H/s';
  const u = ['H/s', 'kH/s', 'MH/s', 'GH/s', 'TH/s'];
  var v = h;
  var i = 0;
  while (v >= 1000 && i < u.length - 1) {
    v /= 1000;
    i++;
  }
  return '${v >= 100 || i == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(2)} ${u[i]}';
}

String humanDuration(int seconds) {
  if (seconds < 60) return '$seconds sn';
  if (seconds < 3600) return '${seconds ~/ 60} dk ${seconds % 60} sn';
  if (seconds < 86400) return '${seconds ~/ 3600} sa ${(seconds % 3600) ~/ 60} dk';
  return '${seconds ~/ 86400} gün ${(seconds % 86400) ~/ 3600} sa';
}

String humanDays(double d) {
  if (d.isInfinite || d.isNaN) return '∞';
  if (d < 1) return '${(d * 24).toStringAsFixed(1)} saat';
  if (d < 60) return '${d.toStringAsFixed(1)} gün';
  if (d < 730) return '${(d / 30).toStringAsFixed(1)} ay';
  return '${(d / 365).toStringAsFixed(1)} yıl';
}

/// 1234.5 -> "1.234,50" (Turkish grouping)
String tl(double v, {int digits = 2}) {
  final neg = v < 0;
  final s = v.abs().toStringAsFixed(digits);
  final parts = s.split('.');
  final buf = StringBuffer();
  final ip = parts[0];
  for (int i = 0; i < ip.length; i++) {
    if (i > 0 && (ip.length - i) % 3 == 0) buf.write('.');
    buf.write(ip[i]);
  }
  return '${neg ? '−' : ''}$buf${digits > 0 ? ',${parts[1]}' : ''}';
}

String xmr(double v) => v >= 0.1 ? v.toStringAsFixed(4) : v >= 0.001 ? v.toStringAsFixed(6) : v.toStringAsFixed(8);

String clock(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
}
