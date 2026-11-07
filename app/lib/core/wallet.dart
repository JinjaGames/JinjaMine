import 'monero_keys.dart';

const _b58 = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

/// Result of a quick Monero address check (format only, no network call).
class AddressCheck {
  const AddressCheck(this.ok, this.message);
  final bool ok;
  final String message;
}

AddressCheck checkMoneroAddress(String raw) {
  final a = raw.trim();
  if (a.isEmpty) return const AddressCheck(false, 'Cüzdan adresi boş.');
  for (final ch in a.split('')) {
    if (!_b58.contains(ch)) return AddressCheck(false, 'Geçersiz karakter: “$ch”. Monero adresleri yalnızca base58 karakterleri içerir.');
  }
  if ((a.length == 95 || a.length == 106) && (a.startsWith('4') || a.startsWith('8')) && !moneroChecksumOk(a)) {
    return const AddressCheck(false, 'Adresin sağlama toplamı tutmuyor: bir karakter eksik ya da yanlış kopyalanmış. Cüzdandan yeniden kopyala.');
  }
  if (a.length == 95 && a.startsWith('4')) return const AddressCheck(true, 'Standart Monero adresi.');
  if (a.length == 95 && a.startsWith('8')) return const AddressCheck(true, 'Monero alt adresi (subaddress).');
  if (a.length == 106 && a.startsWith('4')) {
    return const AddressCheck(true, 'Entegre adres (ödeme kimlikli). Havuzlar çoğu zaman kabul eder ama ana adres daha güvenli.');
  }
  if (a.startsWith('0x')) return const AddressCheck(false, 'Bu bir Ethereum adresi. Monero madenciliği için Monero (XMR) adresi gerekir.');
  if (a.startsWith('5') || a.startsWith('7') || a.startsWith('9') || a.startsWith('A') || a.startsWith('B')) {
    return const AddressCheck(false, 'Bu bir test ağı (stagenet/testnet) adresine benziyor. Ana ağ adresi 4 veya 8 ile başlar.');
  }
  return AddressCheck(false, 'Uzunluk ${a.length}. Monero adresi 95 (ya da entegre adres 106) karakter olmalı ve 4 veya 8 ile başlamalı.');
}

String shortAddress(String a) => a.length < 16 ? a : '${a.substring(0, 8)}…${a.substring(a.length - 6)}';
