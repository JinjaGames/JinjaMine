// Development stand-in for xmrig.exe: reads the same config.json, serves the same local HTTP API
// (/2/summary, /json_rpc pause/resume, PUT /1/config) and prints XMRig-like lines. Used by the tests only.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final cfgPath = args[args.indexOf('--config') + 1];
  var cfg = jsonDecode(File(cfgPath).readAsStringSync()) as Map<String, dynamic>;
  final http = cfg['http'] as Map<String, dynamic>;
  final token = http['access-token'] as String;
  var paused = false;
  var accepted = 0;
  final start = DateTime.now();
  int threads() => ((cfg['cpu'] as Map)['rx'] as List).length;
  double rate() => paused ? 0 : threads() * 650.0;

  stdout.writeln(' * ABOUT        XMRig/6.99.0-fake gcc/13.2.0');
  stdout.writeln(' * POOL #1      ${(cfg['pools'] as List).first['url']} coin monero');
  stdout.writeln('[2026-11-04 12:00:00.000]  cpu      READY threads ${threads()}/${threads()} (${threads()}) huge pages 100% ${threads()}/${threads()} memory 2048 MB');

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, http['port'] as int);
  Timer.periodic(const Duration(seconds: 1), (_) {
    if (!paused) {
      accepted++;
      stdout.writeln('[2026-11-04 12:00:00.000]  cpu      accepted ($accepted/0) diff 120001 (31 ms)');
    }
  });
  await for (final req in server) {
    if (req.headers.value('authorization') != 'Bearer $token') {
      req.response.statusCode = 401;
      await req.response.close();
      continue;
    }
    final body = await utf8.decoder.bind(req).join();
    if (req.method == 'GET' && req.uri.path == '/2/summary') {
      req.response.write(jsonEncode({
        'version': '6.99.0-fake',
        'uptime': DateTime.now().difference(start).inSeconds,
        'paused': paused,
        'algo': 'rx/0',
        'donate_level': cfg['donate-level'],
        'cpu': {'brand': 'AMD Ryzen 9 7950X 16-Core Processor', 'msr': true},
        'hugepages': [threads(), threads()],
        'connection': {'pool': (cfg['pools'] as List).first['url'], 'accepted': accepted, 'rejected': 0, 'diff': 120001, 'ping': 31, 'uptime': 5},
        'results': {'shares_good': accepted, 'shares_total': accepted, 'hashes_total': accepted * 120001},
        'hashrate': {
          'total': [rate(), rate(), null],
          'highest': threads() * 700.0,
          'threads': List.generate(threads(), (_) => [650.0, 650.0, null]),
        },
      }));
    } else if (req.method == 'POST' && req.uri.path == '/json_rpc') {
      final m = (jsonDecode(body) as Map)['method'];
      if (m == 'pause') paused = true;
      if (m == 'resume') paused = false;
      stdout.writeln('[2026-11-04 12:00:00.000]  miner    ${paused ? 'paused' : 'resumed'}');
      req.response.write(jsonEncode({'id': 1, 'jsonrpc': '2.0', 'result': {'status': 'OK'}}));
    } else if (req.method == 'PUT' && req.uri.path == '/1/config') {
      cfg = jsonDecode(body) as Map<String, dynamic>;
      stdout.writeln('[2026-11-04 12:00:00.000]  config   new config applied, threads ${threads()}');
      req.response.statusCode = 204;
    } else {
      req.response.statusCode = 404;
    }
    await req.response.close();
  }
}
