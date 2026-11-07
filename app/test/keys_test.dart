import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jinja_mine/core/monero_keys.dart';

String hex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

void main() {
  test('keccak256 vectors', () {
    expect(hex(keccak256([])), 'c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470');
    expect(hex(keccak256('abc'.codeUnits)), '4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45');
    expect(hex(keccak256(List.filled(200, 0x61))).length, 64); // multi-block path
  });

  test('ed25519 base mult = RFC 8032 test 1 public key', () {
    final secret = hexBytes('9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60');
    final h = sha512.convert(secret).bytes.sublist(0, 32);
    h[0] &= 248;
    h[31] &= 127;
    h[31] |= 64;
    expect(hex(scalarMultBase(leToBig(h))), 'd75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a');
  });

  test('base58 + checksum on real addresses', () {
    const fund = '44AFFq5kSiGBoZ4NMDwYtN18obc8AemS33DBLWs3H7otXft3XjrpDtQGv7SqSsaBYBb98uNbr2VBBEt7f2wfn3RVGQBEP3A';
    final raw = moneroBase58Decode(fund)!;
    expect(raw.length, 69);
    expect(raw[0], 0x12);
    expect(moneroBase58Encode(raw), fund);
    expect(moneroChecksumOk(fund), isTrue);
    expect(moneroChecksumOk(fund.replaceRange(20, 21, fund[20] == 'a' ? 'b' : 'a')), isFalse);
  });

  test('wallet generation round trip', () {
    // Spend key 0x01..: view key must be keccak(spend) mod l, address must decode to the two public keys.
    final w = MoneroWallet.fromSpend(Uint8List.fromList(List.generate(32, (i) => i + 1)));
    expect(w.address.length, 95);
    expect(w.address[0], '4');
    expect(moneroChecksumOk(w.address), isTrue);
    final raw = moneroBase58Decode(w.address)!;
    expect(hex(raw.sublist(1, 33)), hex(w.spendPublic));
    expect(hex(raw.sublist(33, 65)), hex(w.viewPublic));
    expect(hex(w.viewSecret), hex(scReduce32(keccak256(w.spendSecret))));
    final g = MoneroWallet.generate();
    expect(moneroChecksumOk(g.address), isTrue);
    expect(g.address, isNot(w.address));
  });
}
