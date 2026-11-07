import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'settings.dart';

/// How a temperature reading should be presented.
enum TempLevel { unknown, cool, normal, warm, hot }

class TempReading {
  const TempReading(this.celsius, this.level, this.source);
  final double? celsius;
  final TempLevel level;
  final String source;
}

class TempAlert {
  TempAlert(this.device, this.level, this.text) : at = DateTime.now();
  final String device, text;
  final TempLevel level;
  final DateTime at;
}

/// Reads CPU and GPU temperatures.
/// * GPU: nvidia-smi (comes with the NVIDIA driver, no admin needed).
/// * CPU: Windows has no driver-free way to read Ryzen's Tctl. If LibreHardwareMonitor (free, open source) runs,
///   its web server (localhost:8085) or WMI namespace is used; as administrator the ACPI thermal zone is tried last
///   (a motherboard sensor, only approximate).
class HardwareMonitor extends ChangeNotifier {
  HardwareMonitor(this.settings);
  final AppSettings settings;

  double? cpuTemp, gpuTemp, gpuLoad, gpuPower, gpuFan;
  String? gpuName;
  String cpuSource = 'aranıyor…';
  String? gpuError;
  final List<(DateTime, double?, double?)> history = []; // cpu, gpu
  final ValueNotifier<TempAlert?> alerts = ValueNotifier(null);

  Timer? _timer;
  int _tick = 0;
  String? _cpuMethod; // 'lhm-http' | 'lhm-wmi' | 'ohm-wmi' | 'acpi'
  DateTime _lastProbe = DateTime.fromMillisecondsSinceEpoch(0);
  bool _busy = false;
  TempLevel _lastCpuLevel = TempLevel.unknown, _lastGpuLevel = TempLevel.unknown;

  void start() {
    _timer?.cancel();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
  }

  TempReading get cpu => TempReading(cpuTemp, levelFor(cpuTemp, settings.cpuTempLimit, cool: 50), cpuSource);
  TempReading get gpu => TempReading(gpuTemp, levelFor(gpuTemp, settings.gpuTempLimit, cool: 45), gpuName ?? 'nvidia-smi');

  static TempLevel levelFor(double? t, int limit, {required double cool}) {
    if (t == null) return TempLevel.unknown;
    if (t >= limit) return TempLevel.hot;
    if (t >= limit - 10) return TempLevel.warm;
    if (t < cool) return TempLevel.cool;
    return TempLevel.normal;
  }

  Future<void> _poll() async {
    if (_busy) return;
    _busy = true;
    try {
      await _readGpu();
      // CPU via PowerShell/WMI is slower to spawn: every 10 s; the HTTP source every 5 s.
      if (_cpuMethod == 'lhm-http' || _tick.isEven) await _readCpu();
      _tick++;
      history.add((DateTime.now(), cpuTemp, gpuTemp));
      if (history.length > 240) history.removeRange(0, history.length - 240); // ~20 min
      _checkAlerts();
      notifyListeners();
    } finally {
      _busy = false;
    }
  }

  Future<void> _readGpu() async {
    try {
      final r = await Process.run('nvidia-smi', ['--query-gpu=name,temperature.gpu,utilization.gpu,power.draw,fan.speed', '--format=csv,noheader,nounits'])
          .timeout(const Duration(seconds: 4));
      if (r.exitCode != 0) throw Exception('nvidia-smi çıkış kodu ${r.exitCode}');
      final f = (r.stdout as String).trim().split('\n').first.split(',').map((e) => e.trim()).toList();
      gpuName = f[0];
      gpuTemp = double.tryParse(f[1]);
      gpuLoad = double.tryParse(f[2]);
      gpuPower = double.tryParse(f[3]);
      gpuFan = double.tryParse(f[4]);
      gpuError = null;
    } catch (e) {
      gpuTemp = null;
      gpuError = 'Ekran kartı sıcaklığı okunamadı (nvidia-smi yok ya da NVIDIA dışı kart).';
    }
  }

  Future<void> _readCpu() async {
    if (_cpuMethod == null) {
      if (DateTime.now().difference(_lastProbe).inSeconds < 30) return;
      _lastProbe = DateTime.now();
      for (final m in ['lhm-http', 'lhm-wmi', 'ohm-wmi', 'acpi']) {
        final t = await _readWith(m);
        if (t != null) {
          _cpuMethod = m;
          cpuTemp = t;
          cpuSource = _label(m);
          return;
        }
      }
      cpuTemp = null;
      cpuSource = 'okunamıyor';
      return;
    }
    final t = await _readWith(_cpuMethod!);
    if (t == null) {
      _cpuMethod = null; // the source went away (LibreHardwareMonitor closed): probe again
      cpuTemp = null;
      cpuSource = 'okunamıyor';
    } else {
      cpuTemp = t;
    }
  }

  static String _label(String m) => switch (m) {
        'lhm-http' => 'LibreHardwareMonitor',
        'lhm-wmi' => 'LibreHardwareMonitor',
        'ohm-wmi' => 'OpenHardwareMonitor',
        _ => 'ACPI bölgesi (yaklaşık)',
      };

  Future<double?> _readWith(String m) async {
    try {
      switch (m) {
        case 'lhm-http':
          final r = await http.get(Uri.parse('http://127.0.0.1:8085/data.json')).timeout(const Duration(seconds: 2));
          if (r.statusCode != 200) return null;
          return cpuTempFromLhmJson(jsonDecode(r.body));
        case 'lhm-wmi':
        case 'ohm-wmi':
          final ns = m == 'lhm-wmi' ? 'root/LibreHardwareMonitor' : 'root/OpenHardwareMonitor';
          final r = await Process.run('powershell', [
            '-NoProfile',
            '-Command',
            "Get-CimInstance -Namespace $ns -ClassName Sensor -ErrorAction Stop | Where-Object { \$_.SensorType -eq 'Temperature' -and \$_.Identifier -like '*cpu*' } | ForEach-Object { \$_.Name + '=' + \$_.Value }",
          ]).timeout(const Duration(seconds: 6));
          if (r.exitCode != 0) return null;
          return pickCpuTemp({
            for (final l in (r.stdout as String).split('\n'))
              if (l.contains('=')) l.substring(0, l.indexOf('=')).trim(): double.tryParse(l.substring(l.indexOf('=') + 1).trim().replaceAll(',', '.')) ?? 0,
          });
        case 'acpi':
          final r = await Process.run('powershell', [
            '-NoProfile',
            '-Command',
            'Get-CimInstance -Namespace root/wmi -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction Stop | Select-Object -First 1 -ExpandProperty CurrentTemperature',
          ]).timeout(const Duration(seconds: 6));
          final v = double.tryParse((r.stdout as String).trim());
          if (r.exitCode != 0 || v == null) return null;
          final c = v / 10 - 273.15;
          return c > 5 && c < 120 ? c : null;
      }
    } catch (_) {}
    return null;
  }

  /// Picks the most meaningful CPU sensor from name → °C.
  static double? pickCpuTemp(Map<String, double> s) {
    const prefer = ['Core (Tctl/Tdie)', 'CPU Package', 'Tctl', 'Tdie', 'Package', 'CPU'];
    for (final p in prefer) {
      for (final e in s.entries) {
        if (e.key.contains(p) && e.value > 0 && e.value < 130) return e.value;
      }
    }
    final vals = s.values.where((v) => v > 0 && v < 130).toList();
    return vals.isEmpty ? null : vals.reduce((a, b) => a > b ? a : b);
  }

  /// LibreHardwareMonitor's data.json is a tree of {Text, Value: "65.3 °C", Children}; only the CPU branch counts.
  static double? cpuTempFromLhmJson(dynamic root) {
    final found = <String, double>{};
    void walk(dynamic n, bool inCpu) {
      if (n is! Map) return;
      final text = '${n['Text'] ?? ''}';
      final cpuHere = inCpu || '${n['ImageURL'] ?? ''}'.contains('cpu');
      final v = '${n['Value'] ?? ''}';
      if (cpuHere && v.contains('°C')) {
        final d = double.tryParse(v.replaceAll('°C', '').replaceAll(',', '.').trim());
        if (d != null) found[text] = d;
      }
      for (final c in (n['Children'] as List? ?? const [])) {
        walk(c, cpuHere);
      }
    }

    walk(root, false);
    return found.isEmpty ? null : pickCpuTemp(found);
  }

  void _checkAlerts() {
    final c = cpu.level, g = gpu.level;
    if (c != _lastCpuLevel) {
      if (c.index > _lastCpuLevel.index && (c == TempLevel.warm || c == TempLevel.hot)) {
        alerts.value = TempAlert('İşlemci', c, c == TempLevel.hot
            ? 'İşlemci ${cpuTemp!.toStringAsFixed(0)} °C — sınırın (${settings.cpuTempLimit} °C) üstünde.${settings.tempGuard ? ' İş parçacığı azaltılıyor.' : ''}'
            : 'İşlemci ısınıyor: ${cpuTemp!.toStringAsFixed(0)} °C (sınır ${settings.cpuTempLimit} °C).');
      }
      _lastCpuLevel = c;
    }
    if (g != _lastGpuLevel) {
      if (g.index > _lastGpuLevel.index && (g == TempLevel.warm || g == TempLevel.hot)) {
        alerts.value = TempAlert('Ekran kartı', g, g == TempLevel.hot
            ? 'Ekran kartı ${gpuTemp!.toStringAsFixed(0)} °C — sınırın (${settings.gpuTempLimit} °C) üstünde. Kasa hava akışını ve fanları kontrol et.'
            : 'Ekran kartı ısınıyor: ${gpuTemp!.toStringAsFixed(0)} °C.');
      }
      _lastGpuLevel = g;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
