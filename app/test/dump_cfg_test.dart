import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jinja_mine/core/miner.dart';
import 'package:jinja_mine/core/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Writes the generated configs for each payout route (MINE_DUMP_DIR) so they can be checked with `xmrig --dry-run`.
void main() {
  final dir = Platform.environment['MINE_DUMP_DIR'];
  // ignore: avoid_print
  print('dump dir: $dir');
  test('dump configs', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    await s.load();
    s.update(() {
      s.umAddress = 'TLa2f6VPqDgRE67v1736s7bJ8Ray5wYjU7';
      s.nhAddress = 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq';
      s.wallet = '44AFFq5kSiGBoZ4NMDwYtN18obc8AemS33DBLWs3H7otXft3XjrpDtQGv7SqSsaBYBb98uNbr2VBBEt7f2wfn3RVGQBEP3A';
    });
    for (final id in ['unmineable', 'nicehash', 'moneroocean']) {
      s.update(() => s.poolId = id);
      final cfg = MinerController(s).buildConfig(4);
      final f = File('$dir/cfg_$id.json')..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(cfg));
      // ignore: avoid_print
      print('wrote ${f.absolute.path}');
    }
  }, skip: dir == null);
}
