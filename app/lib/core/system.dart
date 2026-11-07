import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Seconds since the last keyboard or mouse input (Windows GetLastInputInfo).
int idleSeconds() {
  final info = calloc<LASTINPUTINFO>();
  try {
    info.ref.cbSize = sizeOf<LASTINPUTINFO>();
    if (!GetLastInputInfo(info)) return 0;
    final now = GetTickCount();
    return ((now - info.ref.dwTime) & 0xFFFFFFFF) ~/ 1000;
  } finally {
    calloc.free(info);
  }
}

/// True when this process runs with administrator rights.
Future<bool> isElevated() async {
  try {
    final r = await Process.run('net', ['session'], runInShell: true);
    return r.exitCode == 0;
  } catch (_) {
    return false;
  }
}

/// Names (lower case) of running executables.
Future<Set<String>> runningExes() async {
  try {
    final r = await Process.run('tasklist', ['/fo', 'csv', '/nh']);
    final out = <String>{};
    for (final line in (r.stdout as String).split('\n')) {
      final l = line.trim();
      if (l.length < 3 || !l.startsWith('"')) continue;
      final end = l.indexOf('"', 1);
      if (end > 1) out.add(l.substring(1, end).toLowerCase());
    }
    return out;
  } catch (_) {
    return {};
  }
}

/// Restarts this app with administrator rights (UAC prompt), then the caller should exit.
Future<bool> relaunchElevated() async {
  final exe = Platform.resolvedExecutable;
  final r = await Process.run('powershell', ['-NoProfile', '-Command', "Start-Process -FilePath '${exe.replaceAll("'", "''")}' -Verb RunAs"]);
  return r.exitCode == 0;
}

const _runKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
const _runName = 'JinjaMine';
const _legacyRunName = 'MineKontrol';

Future<bool> autostartEnabled() async {
  final r = await Process.run('reg', ['query', _runKey, '/v', _runName]);
  return r.exitCode == 0;
}

Future<void> setAutostart(bool on) async {
  if (on) {
    await Process.run('reg', ['add', _runKey, '/v', _runName, '/t', 'REG_SZ', '/d', '"${Platform.resolvedExecutable}" --autostart', '/f']);
  } else {
    await Process.run('reg', ['delete', _runKey, '/v', _runName, '/f']);
  }
}

/// Folder for generated files (XMRig config, encrypted local wallet): %APPDATA%\JinjaMine
Directory dataDir() {
  final base = Platform.environment['APPDATA'] ?? Directory.systemTemp.path;
  final d = Directory('$base\\JinjaMine');
  if (!d.existsSync()) d.createSync(recursive: true);
  return d;
}

/// The app was called "Mine" before it became JinjaMine. Carries the old data over once so nothing is lost:
/// - settings: %APPDATA%\com.jinjagames\Mine -> %APPDATA%\com.jinjagames\JinjaMine (shared_preferences file)
/// - data (XMRig config, encrypted local wallet): %APPDATA%\MineKontrol -> %APPDATA%\JinjaMine
/// - "start with Windows" entry: MineKontrol -> JinjaMine (pointing at this exe)
/// Files are copied, never moved or overwritten, so the old folders stay as a backup.
Future<void> migrateLegacyData() async {
  final base = Platform.environment['APPDATA'];
  if (base == null) return;
  void copyDir(String from, String to) {
    final src = Directory(from);
    if (!src.existsSync()) return;
    Directory(to).createSync(recursive: true);
    for (final e in src.listSync()) {
      if (e is! File) continue;
      final target = File('$to\\${e.uri.pathSegments.last}');
      if (!target.existsSync()) e.copySync(target.path);
    }
  }

  try {
    copyDir('$base\\com.jinjagames\\Mine', '$base\\com.jinjagames\\JinjaMine');
    copyDir('$base\\MineKontrol', '$base\\JinjaMine');
  } catch (_) {}
  try {
    final r = await Process.run('reg', ['query', _runKey, '/v', _legacyRunName]);
    if (r.exitCode == 0) {
      await Process.run('reg', ['delete', _runKey, '/v', _legacyRunName, '/f']);
      await setAutostart(true);
    }
  } catch (_) {}
}

/// The JinjaMine project folder (holds xmrig\, docs\, dist\). Works whatever the folder is called:
/// `PROJECT\dist\JinjaMine\JinjaMine.exe` -> `PROJECT`; otherwise Desktop\JinjaMine (or the old Desktop\mine).
Directory projectDir() {
  final exeDir = File(Platform.resolvedExecutable).parent;
  final dist = exeDir.parent;
  if (dist.uri.pathSegments.where((s) => s.isNotEmpty).last.toLowerCase() == 'dist') return dist.parent;
  final home = Platform.environment['USERPROFILE'] ?? '';
  for (final name in ['JinjaMine', 'mine']) {
    final d = Directory('$home\\Desktop\\$name');
    if (Directory('${d.path}\\xmrig').existsSync() || Directory('${d.path}\\docs').existsSync()) return d;
  }
  return Directory('$home\\Desktop\\JinjaMine');
}

/// Places where xmrig.exe is looked for automatically.
List<String> xmrigCandidates() {
  final exeDir = File(Platform.resolvedExecutable).parent.path;
  return [
    '$exeDir\\xmrig\\xmrig.exe',
    '$exeDir\\xmrig.exe',
    '${File(exeDir).parent.path}\\xmrig\\xmrig.exe',
    '${projectDir().path}\\xmrig\\xmrig.exe',
  ];
}

String? findXmrig() {
  for (final c in xmrigCandidates()) {
    if (File(c).existsSync()) return c;
  }
  // also accept xmrig-6.x.y\xmrig.exe unpacked into the project's xmrig folder
  final d = Directory('${projectDir().path}\\xmrig');
  if (d.existsSync()) {
    for (final e in d.listSync(recursive: true)) {
      if (e is File && e.path.toLowerCase().endsWith('\\xmrig.exe')) return e.path;
    }
  }
  return null;
}
