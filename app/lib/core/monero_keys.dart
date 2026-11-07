import 'dart:math';
import 'dart:typed_data';

// Monero key and address maths: Keccak-256 (original padding, as Monero uses), ed25519 base-point
// multiplication and Monero's block-wise base58. Used to (1) verify address checksums and (2) create a local
// wallet for the "mine now, connect a wallet later" option. Tested against RFC 8032 and known addresses.

// ---------------------------------------------------------------- Keccak-256
const _rc = <int>[
  0x0000000000000001, 0x0000000000008082, 0x800000000000808A, 0x8000000080008000, //
  0x000000000000808B, 0x0000000080000001, 0x8000000080008081, 0x8000000000008009,
  0x000000000000008A, 0x0000000000000088, 0x0000000080008009, 0x000000008000000A,
  0x000000008000808B, 0x800000000000008B, 0x8000000000008089, 0x8000000000008003,
  0x8000000000008002, 0x8000000000000080, 0x000000000000800A, 0x800000008000000A,
  0x8000000080008081, 0x8000000000008080, 0x0000000080000001, 0x8000000080008008,
];
const _rot = <int>[0, 1, 62, 28, 27, 36, 44, 6, 55, 20, 3, 10, 43, 25, 39, 41, 45, 15, 21, 8, 18, 2, 61, 56, 14];

int _rotl(int x, int n) => n == 0 ? x : (x << n) | (x >>> (64 - n));

void _keccakF(List<int> a) {
  final b = List<int>.filled(25, 0), c = List<int>.filled(5, 0), d = List<int>.filled(5, 0);
  for (int round = 0; round < 24; round++) {
    for (int x = 0; x < 5; x++) {
      c[x] = a[x] ^ a[x + 5] ^ a[x + 10] ^ a[x + 15] ^ a[x + 20];
    }
    for (int x = 0; x < 5; x++) {
      d[x] = c[(x + 4) % 5] ^ _rotl(c[(x + 1) % 5], 1);
    }
    for (int i = 0; i < 25; i++) {
      a[i] ^= d[i % 5];
    }
    for (int x = 0; x < 5; x++) {
      for (int y = 0; y < 5; y++) {
        b[y + 5 * ((2 * x + 3 * y) % 5)] = _rotl(a[x + 5 * y], _rot[x + 5 * y]);
      }
    }
    for (int x = 0; x < 5; x++) {
      for (int y = 0; y < 5; y++) {
        a[x + 5 * y] = b[x + 5 * y] ^ (~b[(x + 1) % 5 + 5 * y] & b[(x + 2) % 5 + 5 * y]);
      }
    }
    a[0] ^= _rc[round];
  }
}

Uint8List keccak256(List<int> input) {
  const rate = 136;
  final padded = Uint8List(((input.length ~/ rate) + 1) * rate)..setRange(0, input.length, input);
  padded[input.length] ^= 0x01;
  padded[padded.length - 1] ^= 0x80;
  final st = List<int>.filled(25, 0);
  final bd = ByteData.sublistView(padded);
  for (int off = 0; off < padded.length; off += rate) {
    for (int i = 0; i < rate ~/ 8; i++) {
      st[i] ^= bd.getUint64(off + i * 8, Endian.little);
    }
    _keccakF(st);
  }
  final out = ByteData(32);
  for (int i = 0; i < 4; i++) {
    out.setUint64(i * 8, st[i], Endian.little);
  }
  return out.buffer.asUint8List();
}

// ---------------------------------------------------------------- ed25519
final _p = (BigInt.one << 255) - BigInt.from(19);
final _l = (BigInt.one << 252) + BigInt.parse('27742317777372353535851937790883648493');
final _d = (BigInt.from(-121665) * BigInt.from(121666).modInverse(_p)) % _p;
final _bx = BigInt.parse('15112221349535400772501151409588531511454012693041857206046113283949847762202');
final _by = BigInt.parse('46316835694926478169428394003475163141307993866256225615783033603165251855960');

class _Pt {
  const _Pt(this.x, this.y, this.z, this.t);
  final BigInt x, y, z, t;
}

_Pt _add(_Pt a, _Pt b) {
  final aa = ((a.y - a.x) * (b.y - b.x)) % _p;
  final bb = ((a.y + a.x) * (b.y + b.x)) % _p;
  final cc = (BigInt.two * a.t * b.t * _d) % _p;
  final dd = (BigInt.two * a.z * b.z) % _p;
  final e = bb - aa, f = dd - cc, g = dd + cc, h = bb + aa;
  return _Pt((e * f) % _p, (g * h) % _p, (f * g) % _p, (e * h) % _p);
}

_Pt _mul(BigInt k) {
  var q = _Pt(BigInt.zero, BigInt.one, BigInt.one, BigInt.zero);
  var b = _Pt(_bx, _by, BigInt.one, (_bx * _by) % _p);
  while (k > BigInt.zero) {
    if (k.isOdd) q = _add(q, b);
    b = _add(b, b);
    k = k >> 1;
  }
  return q;
}

BigInt _le(List<int> b) {
  var v = BigInt.zero;
  for (int i = b.length - 1; i >= 0; i--) {
    v = (v << 8) | BigInt.from(b[i]);
  }
  return v;
}

Uint8List _toLe32(BigInt v) {
  final out = Uint8List(32);
  for (int i = 0; i < 32; i++) {
    out[i] = (v & BigInt.from(0xff)).toInt();
    v = v >> 8;
  }
  return out;
}

/// k·B, encoded the ed25519 way (y little-endian, sign of x in the top bit).
Uint8List scalarMultBase(BigInt k) {
  final q = _mul(k);
  final zi = q.z.modInverse(_p);
  final x = (q.x * zi) % _p, y = (q.y * zi) % _p;
  final out = _toLe32(y);
  if (x.isOdd) out[31] |= 0x80;
  return out;
}

/// Monero sc_reduce32: interpret 32 bytes little-endian and reduce mod l.
Uint8List scReduce32(List<int> b) => _toLe32(_le(b) % _l);

BigInt leToBig(List<int> b) => _le(b);

// ---------------------------------------------------------------- Monero base58
const _alpha = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
const _encSizes = [0, 2, 3, 5, 6, 7, 9, 10, 11];

String moneroBase58Encode(List<int> data) {
  final sb = StringBuffer();
  for (int off = 0; off < data.length; off += 8) {
    final block = data.sublist(off, min(off + 8, data.length));
    var num = BigInt.zero;
    for (final x in block) {
      num = (num << 8) | BigInt.from(x);
    }
    final size = _encSizes[block.length];
    final chars = List.filled(size, '1');
    for (int i = size - 1; i >= 0 && num > BigInt.zero; i--) {
      chars[i] = _alpha[(num % BigInt.from(58)).toInt()];
      num = num ~/ BigInt.from(58);
    }
    sb.writeAll(chars);
  }
  return sb.toString();
}

/// Null when [s] is not valid Monero base58.
Uint8List? moneroBase58Decode(String s) {
  final out = <int>[];
  for (int off = 0; off < s.length; off += 11) {
    final block = s.substring(off, min(off + 11, s.length));
    final size = _encSizes.indexOf(block.length);
    if (size < 0) return null;
    var num = BigInt.zero;
    for (final ch in block.split('')) {
      final v = _alpha.indexOf(ch);
      if (v < 0) return null;
      num = num * BigInt.from(58) + BigInt.from(v);
    }
    if (num >> (size * 8) != BigInt.zero) return null;
    final bytes = List<int>.filled(size, 0);
    for (int i = size - 1; i >= 0; i--) {
      bytes[i] = (num & BigInt.from(0xff)).toInt();
      num = num >> 8;
    }
    out.addAll(bytes);
  }
  return Uint8List.fromList(out);
}

/// True when the last 4 bytes of the decoded address match its Keccak checksum.
bool moneroChecksumOk(String address) {
  final raw = moneroBase58Decode(address);
  if (raw == null || raw.length < 5) return false;
  final body = raw.sublist(0, raw.length - 4);
  final sum = keccak256(body).sublist(0, 4);
  for (int i = 0; i < 4; i++) {
    if (sum[i] != raw[raw.length - 4 + i]) return false;
  }
  return true;
}

String _hex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

Uint8List hexBytes(String h) => Uint8List.fromList([for (int i = 0; i + 1 < h.length; i += 2) int.parse(h.substring(i, i + 2), radix: 16)]);

/// A standard (deterministic) Monero mainnet wallet: the view key is derived from the spend key exactly like the
/// 25-word-seed wallets, so Feather / Monero GUI / Cake can restore it from "address + view key + spend key".
class MoneroWallet {
  MoneroWallet._(this.spendSecret, this.viewSecret, this.spendPublic, this.viewPublic, this.address);
  final Uint8List spendSecret, viewSecret, spendPublic, viewPublic;
  final String address;

  String get spendKeyHex => _hex(spendSecret);
  String get viewKeyHex => _hex(viewSecret);

  factory MoneroWallet.fromSpend(List<int> seed32) {
    final s = scReduce32(seed32);
    final v = scReduce32(keccak256(s));
    final sPub = scalarMultBase(_le(s));
    final vPub = scalarMultBase(_le(v));
    final body = <int>[0x12, ...sPub, ...vPub];
    final addr = moneroBase58Encode([...body, ...keccak256(body).sublist(0, 4)]);
    return MoneroWallet._(s, v, sPub, vPub, addr);
  }

  factory MoneroWallet.generate() {
    final r = Random.secure();
    return MoneroWallet.fromSpend(List<int>.generate(32, (_) => r.nextInt(256)));
  }
}
