import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jinja_mine/core/local_wallet.dart';
import 'package:jinja_mine/core/monero_keys.dart';

void main() {
  test('local wallet: DPAPI round trip, no overwrite', () {
    final dir = Directory.systemTemp.createTempSync('mine_lw');
    LocalWalletStore.pathOverride = '${dir.path}/w.bin';
    try {
      expect(LocalWalletStore.exists, isFalse);
      final w = LocalWalletStore.create(restoreHeight: 3799247);
      expect(moneroChecksumOk(w.address), isTrue);
      final raw = File(LocalWalletStore.pathOverride!).readAsBytesSync();
      expect(String.fromCharCodes(raw).contains(w.wallet.spendKeyHex), isFalse); // encrypted on disk
      final back = LocalWalletStore.load()!;
      expect(back.address, w.address);
      expect(back.wallet.spendKeyHex, w.wallet.spendKeyHex);
      expect(back.restoreHeight, 3799247);
      expect(() => LocalWalletStore.create(), throwsStateError);
      expect(w.backupText(), contains(w.wallet.viewKeyHex));
    } finally {
      dir.deleteSync(recursive: true);
    }
  });
}
