import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'monero_keys.dart';
import 'system.dart';

// "Mine now, connect a wallet later": a Monero wallet created on this PC. The keys never leave the machine; they
// are stored encrypted with Windows DPAPI (only this Windows user can decrypt them) in %APPDATA%/JinjaMine.

final class _Blob extends Struct {
  @Uint32()
  external int cbData;
  external Pointer<Uint8> pbData;
}

typedef _ProtC = Int32 Function(Pointer<_Blob>, Pointer<Utf16>, Pointer<_Blob>, Pointer, Pointer, Uint32, Pointer<_Blob>);
typedef _ProtD = int Function(Pointer<_Blob>, Pointer<Utf16>, Pointer<_Blob>, Pointer, Pointer, int, Pointer<_Blob>);
typedef _UnprotC = Int32 Function(Pointer<_Blob>, Pointer<Pointer<Utf16>>, Pointer<_Blob>, Pointer, Pointer, Uint32, Pointer<_Blob>);
typedef _UnprotD = int Function(Pointer<_Blob>, Pointer<Pointer<Utf16>>, Pointer<_Blob>, Pointer, Pointer, int, Pointer<_Blob>);

final _crypt32 = DynamicLibrary.open('crypt32.dll');
final _kernel32 = DynamicLibrary.open('kernel32.dll');
final _protect = _crypt32.lookupFunction<_ProtC, _ProtD>('CryptProtectData');
final _unprotect = _crypt32.lookupFunction<_UnprotC, _UnprotD>('CryptUnprotectData');
final _localFree = _kernel32.lookupFunction<Pointer Function(Pointer), Pointer Function(Pointer)>('LocalFree');

Uint8List _dpapi(Uint8List data, {required bool encrypt}) {
  return using((arena) {
    final inBlob = arena<_Blob>();
    final outBlob = arena<_Blob>();
    final buf = arena<Uint8>(data.length);
    buf.asTypedList(data.length).setAll(0, data);
    inBlob.ref
      ..cbData = data.length
      ..pbData = buf;
    const uiForbidden = 0x1;
    final ok = encrypt
        ? _protect(inBlob, 'JinjaMine yerel cuzdan'.toNativeUtf16(allocator: arena), nullptr, nullptr, nullptr, uiForbidden, outBlob)
        : _unprotect(inBlob, nullptr, nullptr, nullptr, nullptr, uiForbidden, outBlob);
    if (ok == 0) throw StateError('Windows DPAPI ${encrypt ? 'şifreleme' : 'çözme'} başarısız.');
    final out = Uint8List.fromList(outBlob.ref.pbData.asTypedList(outBlob.ref.cbData));
    _localFree(outBlob.ref.pbData.cast());
    return out;
  });
}

class LocalWalletInfo {
  LocalWalletInfo({required this.wallet, required this.createdAt, required this.restoreHeight});
  final MoneroWallet wallet;
  final DateTime createdAt;
  final int? restoreHeight;

  String get address => wallet.address;

  /// Plain-text backup the user saves somewhere safe (contains the private spend key).
  String backupText() => '''JinjaMine — yerel Monero cüzdanı (YEDEK)
Oluşturulma: ${createdAt.toIso8601String()}

Bu dosyadaki “gizli harcama anahtarı” paraya erişim demektir. Kimseyle paylaşma, buluta yükleme,
yazdırıp ya da şifreli bir USB'de sakladıktan sonra bu dosyayı sil.

Adres (herkese açık):
${wallet.address}

Gizli görüntüleme anahtarı (private view key):
${wallet.viewKeyHex}

Gizli harcama anahtarı (private spend key):
${wallet.spendKeyHex}

Geri yükleme yüksekliği (restore height): ${restoreHeight ?? 'bilinmiyor — 0 yaz'}

Paraya erişmek için: Feather Wallet → “Restore wallet from keys” (ya da Monero GUI → “Anahtarlardan geri yükle”,
Cake Wallet → “Restore → Keys”). Adresi, görüntüleme ve harcama anahtarını ve geri yükleme yüksekliğini gir.
''';
}

class LocalWalletStore {
  static String? pathOverride; // tests only
  static File get _file => File(pathOverride ?? '${dataDir().path}\\yerel_cuzdan.bin');

  static bool get exists => _file.existsSync();

  static LocalWalletInfo? load() {
    if (!exists) return null;
    try {
      final j = jsonDecode(utf8.decode(_dpapi(_file.readAsBytesSync(), encrypt: false))) as Map<String, dynamic>;
      final w = MoneroWallet.fromSpend(hexBytes(j['spend'] as String));
      if (w.address != j['address']) throw StateError('adres anahtarla uyuşmuyor');
      return LocalWalletInfo(wallet: w, createdAt: DateTime.parse(j['created'] as String), restoreHeight: j['height'] as int?);
    } catch (_) {
      return null;
    }
  }

  /// Creates and stores a new wallet. Refuses to overwrite an existing one (it may hold mined coins).
  static LocalWalletInfo create({int? restoreHeight}) {
    if (exists) throw StateError('Zaten bir yerel cüzdan var; üzerine yazılmaz.');
    final w = MoneroWallet.generate();
    final info = LocalWalletInfo(wallet: w, createdAt: DateTime.now(), restoreHeight: restoreHeight);
    final j = jsonEncode({'address': w.address, 'spend': w.spendKeyHex, 'created': info.createdAt.toIso8601String(), 'height': restoreHeight});
    _file.writeAsBytesSync(_dpapi(Uint8List.fromList(utf8.encode(j)), encrypt: true), flush: true);
    return info;
  }
}
