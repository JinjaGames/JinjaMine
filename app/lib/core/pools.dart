/// How a pool pays out, which decides what kind of address it needs.
enum Payout {
  xmr, // a Monero address (4… / 8…)
  anyCoin, // unMineable: mine RandomX, get paid in the coin you choose (e.g. TRX, LTC on Binance)
  btcNiceHash, // NiceHash: sells the hash power, pays BTC to a NiceHash mining address
}

/// Known pools. [statsApi] follows the nodejs-pool format (/miner/{wallet}/stats and /payments).
class PoolPreset {
  const PoolPreset({
    required this.id,
    required this.name,
    required this.url,
    required this.tls,
    required this.feePct,
    required this.minPayout,
    required this.note,
    this.payout = Payout.xmr,
    this.statsApi,
    this.dashboard,
    this.passIsWorker = true,
    this.advanced = false,
  });

  final String id, name, url, note;
  final bool tls, advanced;
  final double feePct;
  final double minPayout; // XMR (for XMR pools)
  final Payout payout;
  final String? statsApi; // base, e.g. https://www.supportxmr.com/api
  final String? dashboard; // web page, {wallet} is replaced
  final bool passIsWorker;

  String get host => url.contains(':') ? url.substring(0, url.lastIndexOf(':')) : url;
  int get port => int.tryParse(url.substring(url.lastIndexOf(':') + 1)) ?? 443;
}

const pools = <PoolPreset>[
  PoolPreset(
    id: 'supportxmr',
    name: 'SupportXMR',
    url: 'pool.supportxmr.com:443',
    tls: true,
    feePct: 0.6,
    minPayout: 0.003,
    statsApi: 'https://www.supportxmr.com/api',
    dashboard: 'https://www.supportxmr.com/#/dashboard',
    note: 'Büyük, eski ve güvenilir PPLNS havuzu. %0,6 ücret. Varsayılan ödeme eşiği 0,1 XMR; panelden 0,003 XMR’ye kadar düşürülebilir.',
  ),
  PoolPreset(
    id: 'moneroocean',
    name: 'MoneroOcean',
    url: 'gulf.moneroocean.stream:20128',
    tls: true,
    feePct: 0.0,
    minPayout: 0.003,
    statsApi: 'https://api.moneroocean.stream',
    dashboard: 'https://moneroocean.stream/#/dashboard?addr={wallet}',
    note: 'Ödemesi XMR olan, ücretsiz PPLNS havuzu. Kendi XMRig sürümüyle en kârlı algoritmaya geçer; standart XMRig ile düz RandomX (rx/0) kazılır.',
  ),
  PoolPreset(
    id: 'hashvault',
    name: 'HashVault',
    url: 'pool.hashvault.pro:443',
    tls: true,
    feePct: 0.9,
    minPayout: 0.01,
    dashboard: 'https://monero.hashvault.pro/en/dashboard',
    note: 'Yaygın bir PPLNS havuzu. %0,9 ücret. İstatistikler web panelinden izlenir.',
  ),
  PoolPreset(
    id: 'unmineable',
    name: 'unMineable (istediğin coinle ödeme)',
    url: 'rx.unmineable.com:443',
    tls: true,
    feePct: 1.0,
    minPayout: 0,
    payout: Payout.anyCoin,
    dashboard: 'https://unmineable.com/coins/{coin}/address/{wallet}',
    note: 'RandomX kazarsın, ödemeyi seçtiğin coinle alırsın (TRX, LTC, DOGE, USDT…). Binance gibi XMR desteklemeyen borsalara doğrudan ödeme için. %1 ücret.',
  ),
  PoolPreset(
    id: 'nicehash',
    name: 'NiceHash (BTC ile ödeme)',
    url: 'randomxmonero.auto.nicehash.com:443',
    tls: true,
    feePct: 2.0,
    minPayout: 0,
    payout: Payout.btcNiceHash,
    dashboard: 'https://www.nicehash.com/my/mining/rigs',
    note: 'Kazmazsın, işlem gücünü kiraya verirsin; ödeme BTC. Fiyatı saatten saate değişir, bazen XMR kazmaktan kârlıdır. NiceHash hesabının madencilik adresi gerekir. ~%2 ücret.',
  ),
  PoolPreset(
    id: 'p2pool',
    name: 'P2Pool (yerel)',
    url: '127.0.0.1:3333',
    tls: false,
    feePct: 0.0,
    minPayout: 0.0,
    advanced: true,
    note: 'Merkezi olmayan havuz, ücret yok, ödeme doğrudan bloktan gelir. Bilgisayarda monerod (tam düğüm, ~250 GB) ve p2pool çalışıyor olmalı; cüzdan adresi p2pool’a verilir. İleri düzey.',
    passIsWorker: false,
  ),
  PoolPreset(
    id: 'custom',
    name: 'Özel havuz',
    url: '',
    tls: true,
    feePct: 0.0,
    minPayout: 0.0,
    advanced: true,
    note: 'Adresi kendin gir (ör. havuz.ornek.com:443).',
  ),
];

PoolPreset poolById(String id) => pools.firstWhere((p) => p.id == id, orElse: () => pools.first);

/// Coins unMineable can pay out that Binance (and most exchanges) accept without a memo/tag.
/// [network] is what to pick on the exchange's deposit page; [regex] matches unMineable's own address check.
class PayoutCoin {
  const PayoutCoin(this.symbol, this.name, this.network, this.regex, this.note);
  final String symbol, name, network, note;
  final String regex;
  bool valid(String a) => RegExp(regex).hasMatch(a.trim());
}

const payoutCoins = <PayoutCoin>[
  PayoutCoin('TRX', 'TRON', 'TRX (TRON / TRC20)', r'^T[1-9A-HJ-NP-Za-km-z]{33}$', 'Önerilen: ağ ücreti çok düşük, eşik 15 TRX (birkaç dolar), Binance’ta doğrudan yatırılır.'),
  PayoutCoin('LTC', 'Litecoin', 'LTC (Litecoin)', r'^(L|M|3)[A-Za-z0-9]{33}$|^(ltc1)[0-9A-Za-z]{39}$', 'Düşük ücret, her borsada var.'),
  PayoutCoin('DOGE', 'Dogecoin', 'DOGE (Dogecoin)', r'^(D|A|9)[a-km-zA-HJ-NP-Z1-9]{33,34}$', 'Düşük ücret.'),
  PayoutCoin('USDT', 'Tether (TRC20)', 'TRX (TRON / TRC20)', r'^T[1-9A-HJ-NP-Za-km-z]{33}$', 'Dolara sabit. Binance’ta ağ olarak MUTLAKA TRC20 seç; eşik TRX’ten yüksektir.'),
  PayoutCoin('BTC', 'Bitcoin', 'BTC (Bitcoin)', r'^[13][a-km-zA-HJ-NP-Z1-9]{25,34}$|^(bc1)[0-9A-Za-z]{39,59}$', 'Ödeme eşiği ve ağ ücreti yüksek; küçük kazançta yavaş birikir.'),
  PayoutCoin('XMR', 'Monero', 'XMR (Monero)', r'^[48][0-9A-Za-z]{94}([0-9A-Za-z]{11})?$', 'XMR’yi kendi cüzdanına almak için doğrudan XMR havuzları daha ucuzdur.'),
];

PayoutCoin payoutCoinBy(String s) => payoutCoins.firstWhere((c) => c.symbol == s, orElse: () => payoutCoins.first);

/// NiceHash mining addresses are Bitcoin addresses (legacy, P2SH or bech32).
bool validBtcAddress(String a) => RegExp(r'^[13][a-km-zA-HJ-NP-Z1-9]{25,34}$|^(bc1)[0-9a-z]{39,59}$').hasMatch(a.trim());
