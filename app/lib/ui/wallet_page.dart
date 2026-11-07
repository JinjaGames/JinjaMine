import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/local_wallet.dart';
import '../core/pools.dart';
import '../core/system.dart';
import '../core/wallet.dart';
import 'theme.dart';
import 'widgets.dart';

enum _Route { exchange, ownXmr, noWallet, nicehash }

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});
  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  late final TextEditingController _wallet, _worker, _custom, _um, _nh;
  bool _inited = false;
  _Route? _route;
  LocalWalletInfo? _local;
  bool _showKeys = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;
    _inited = true;
    final s = AppScope.of(context).settings;
    _wallet = TextEditingController(text: s.walletIsLocal ? '' : s.wallet);
    _worker = TextEditingController(text: s.worker);
    _custom = TextEditingController(text: s.customUrl);
    _um = TextEditingController(text: s.umAddress);
    _nh = TextEditingController(text: s.nhAddress);
    _local = LocalWalletStore.load();
  }

  _Route _routeFrom() {
    final s = AppScope.of(context).settings;
    final p = poolById(s.poolId);
    if (p.payout == Payout.anyCoin) return _Route.exchange;
    if (p.payout == Payout.btcNiceHash) return _Route.nicehash;
    if (s.walletIsLocal) return _Route.noWallet;
    return _Route.ownXmr;
  }

  Future<void> _open(String url) async {
    if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication) && mounted) snack(context, 'Açılamadı: $url', error: true);
  }

  /// Applies a payout change: saves, refreshes balances and restarts a running miner.
  void _apply(void Function() change, String msg) {
    final app = AppScope.of(context);
    final before = '${app.settings.poolId}|${app.settings.payoutAddress()}|${app.settings.umCoin}';
    app.settings.update(change);
    final after = '${app.settings.poolId}|${app.settings.payoutAddress()}|${app.settings.umCoin}';
    app.poolStats.refresh();
    app.profit.compute();
    final restart = app.miner.busy && before != after;
    snack(context, restart ? '$msg Madenci yeni ödeme adresiyle yeniden başlatılıyor.' : msg);
    if (restart) app.miner.restart();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.settings, m = app.miner;
    return ListenableBuilder(
      listenable: Listenable.merge([s, m]),
      builder: (context, _) {
        final route = _route ?? _routeFrom();
        return ListView(padding: const EdgeInsets.all(20), children: [
          Section(
            title: 'Ödemeyi nereye alacaksın?',
            icon: Icons.alt_route,
            subtitle: 'Kazanç havuzda birikir ve eşiğe ulaşınca bu adrese gönderilir. Adres herkese açık bir bilgidir (IBAN gibi); '
                'cüzdanın kurtarma kelimeleri ya da şifresi ASLA buraya yazılmaz.',
            child: LayoutBuilder(builder: (context, c) {
              final cards = [
                _choice(_Route.exchange, Icons.currency_exchange, 'Binance / borsa', 'XMR’yi desteklemeyen borsaya doğrudan ödeme (TRX, LTC, USDT…)', route),
                _choice(_Route.ownXmr, Icons.account_balance_wallet, 'Kendi Monero cüzdanım', 'Feather, Cake ya da Monero GUI adresi (en düşük ücret)', route),
                _choice(_Route.noWallet, Icons.hourglass_empty, 'Henüz cüzdanım yok', 'Şimdi kaz, cüzdanı sonra bağla (bu bilgisayarda cüzdan oluşturulur)', route),
                _choice(_Route.nicehash, Icons.storefront, 'NiceHash hesabı', 'Hash gücünü kirala, BTC al', route),
              ];
              final cols = c.maxWidth > 1000 ? 4 : c.maxWidth > 560 ? 2 : 1;
              final w = (c.maxWidth - 12 * (cols - 1)) / cols;
              return Wrap(spacing: 12, runSpacing: 12, children: [for (final k in cards) SizedBox(width: w, child: k)]);
            }),
          ),
          const SizedBox(height: 16),
          switch (route) {
            _Route.exchange => _exchange(),
            _Route.ownXmr => _ownXmr(),
            _Route.noWallet => _noWallet(),
            _Route.nicehash => _niceHash(),
          },
          const SizedBox(height: 16),
          Section(
            title: 'Bu bilgisayarın adı (worker)',
            icon: Icons.computer,
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _worker,
                  decoration: const InputDecoration(helperText: 'Havuz panelinde bu adla görünür. Birden çok bilgisayar varsa her birine farklı ad ver.'),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: () => _apply(() => s.worker = _worker.text.trim().isEmpty ? 'jinjamine' : _worker.text.trim(), 'Kaydedildi.'),
                child: const Text('Kaydet'),
              ),
            ]),
          ),
        ]);
      },
    );
  }

  Widget _choice(_Route r, IconData icon, String title, String text, _Route cur) {
    final sel = r == cur;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _route = r),
      child: Container(
        height: 104,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: sel ? Pal.orange.withValues(alpha: 0.1) : Pal.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? Pal.orange : Pal.line, width: sel ? 1.5 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: sel ? Pal.orange : Pal.muted),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
            if (sel) const Icon(Icons.check_circle, color: Pal.orange, size: 18),
          ]),
          const SizedBox(height: 6),
          Text(text, style: const TextStyle(color: Pal.muted, fontSize: 12, height: 1.3)),
        ]),
      ),
    );
  }

  Widget _status(bool ok, String text) => Row(children: [
        Icon(ok ? Icons.check_circle : Icons.info_outline, size: 16, color: ok ? Pal.ok : Pal.amber),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: TextStyle(color: ok ? Pal.ok : Pal.amber, fontSize: 12.5))),
      ]);

  Widget _pasteField(TextEditingController c, String label) => TextField(
        controller: c,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(fontFamily: 'Consolas', fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: IconButton(
            tooltip: 'Panodan yapıştır',
            icon: const Icon(Icons.content_paste),
            onPressed: () async {
              final d = await Clipboard.getData('text/plain');
              if (d?.text != null) setState(() => c.text = d!.text!.trim());
            },
          ),
        ),
      );

  Widget _steps(List<String> steps) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (int i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Pal.orange.withValues(alpha: 0.18), shape: BoxShape.circle),
                child: Text('${i + 1}', style: const TextStyle(color: Pal.orange, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(steps[i], style: const TextStyle(height: 1.4))),
            ]),
          ),
      ]);

  // ---------------------------------------------------------------- Binance / exchange
  Widget _exchange() {
    final s = AppScope.of(context).settings;
    final coin = payoutCoinBy(s.umCoin);
    final valid = coin.valid(_um.text);
    final active = s.poolId == 'unmineable';
    return Section(
      title: 'Binance (ya da başka borsa) ile',
      icon: Icons.currency_exchange,
      trailing: active ? const StatusPill('ETKİN', Pal.ok, icon: Icons.check) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Pal.amber.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: Pal.amber.withValues(alpha: 0.4))),
          child: const Text(
            'Binance, Monero’yu (XMR) Şubat 2024’te listeden çıkardı: XMR yatırma adresi vermez, XMR havuzunun ödemesini doğrudan Binance’a gönderemezsin. '
            'Çözüm: unMineable havuzunda aynı RandomX işini yap, ödemeyi Binance’ın kabul ettiği bir coinle al. Ücret %1 (XMR havuzlarında %0–0,9).',
            style: TextStyle(height: 1.4),
          ),
        ),
        const SizedBox(height: 12),
        const Text('Ödeme coini', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final c in payoutCoins)
            ChoiceChip(
              label: Text(c.symbol == 'USDT' ? 'USDT (TRC20)' : c.symbol),
              selected: c.symbol == s.umCoin,
              onSelected: (_) => setState(() => s.update(() => s.umCoin = c.symbol)),
            ),
        ]),
        const SizedBox(height: 6),
        Text(coin.note, style: const TextStyle(color: Pal.muted, fontSize: 12.5)),
        const SizedBox(height: 12),
        const Text('Binance’ta adresi bulmak', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        _steps([
          'Binance uygulamasında (ya da sitesinde) Cüzdan → Yatır (Deposit) → Kripto yatır.',
          'Coin olarak ${coin.symbol} ara ve seç.',
          'Ağ (network) olarak ${coin.network} seç. Yanlış ağ seçilirse para kaybolabilir.',
          'Gösterilen adresi kopyala${coin.symbol == 'TRX' || coin.symbol == 'USDT' ? ' (T ile başlar)' : ''} ve aşağıya yapıştır. Memo/etiket istenmez; isteyen coinleri (XRP, XLM, BNB-BEP2) seçme.',
          'Kaydet’e bas. Havuz eşiği dolunca (${coin.symbol == 'TRX' ? '15 TRX' : 'coine göre değişir'}) ödeme otomatik olarak Binance hesabına düşer.',
        ]),
        const Text('Binance TR ya da başka bir borsa da aynı şekilde çalışır; önemli olan coin ve ağın eşleşmesidir.', style: TextStyle(color: Pal.muted, fontSize: 12)),
        const SizedBox(height: 12),
        _pasteField(_um, '${coin.symbol} yatırma adresi (${coin.network})'),
        const SizedBox(height: 8),
        if (_um.text.trim().isNotEmpty) _status(valid, valid ? 'Adres biçimi ${coin.symbol} için doğru.' : 'Bu, ${coin.network} adresine benzemiyor. Coin ve ağı kontrol et.'),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 8, children: [
          FilledButton.icon(
            onPressed: !valid
                ? null
                : () => _apply(() {
                      s.umAddress = _um.text.trim();
                      s.poolId = 'unmineable';
                    }, 'unMineable seçildi: ödeme ${coin.symbol} olarak gelecek.'),
            icon: const Icon(Icons.save),
            label: Text(active ? 'Adresi kaydet' : 'Kaydet ve bu yolu kullan'),
          ),
          OutlinedButton.icon(onPressed: () => _open('https://www.binance.com/tr/my/wallet/account/main/deposit/crypto/${coin.symbol}'), icon: const Icon(Icons.open_in_new, size: 16), label: const Text('Binance yatırma sayfası')),
          if (s.umAddress.isNotEmpty)
            OutlinedButton.icon(
                onPressed: () => _open('https://unmineable.com/coins/${s.umCoin}/address/${s.umAddress}'), icon: const Icon(Icons.open_in_new, size: 16), label: const Text('unMineable panelim')),
        ]),
      ]),
    );
  }

  // ---------------------------------------------------------------- own XMR wallet
  Widget _ownXmr() {
    final app = AppScope.of(context);
    final s = app.settings;
    final check = checkMoneroAddress(_wallet.text);
    final xmrPools = pools.where((p) => p.payout == Payout.xmr).toList();
    final usingXmrPool = poolById(s.poolId).payout == Payout.xmr;
    return Column(children: [
      Section(
        title: 'Monero (XMR) cüzdan adresin',
        icon: Icons.account_balance_wallet,
        trailing: usingXmrPool && !s.walletIsLocal && s.wallet.isNotEmpty ? const StatusPill('ETKİN', Pal.ok, icon: Icons.check) : null,
        subtitle: 'Cüzdanın yoksa: Feather (masaüstü) ya da Cake Wallet (telefon) kur → yeni cüzdan → 16/25 kurtarma kelimesini kâğıda yaz → “Receive/Al” ekranındaki 4… ile başlayan adresi kopyala.',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _pasteField(_wallet, 'XMR adresi (4… veya 8… ile başlar)'),
          const SizedBox(height: 8),
          if (_wallet.text.trim().isNotEmpty) _status(check.ok, check.message),
          if (s.walletIsLocal && _local != null) ...[
            const SizedBox(height: 8),
            Text('Şu an bu bilgisayarda oluşturulan yerel cüzdana (${shortAddress(_local!.address)}) kazıyorsun. Kendi adresini kaydedince yeni kazanç oraya gider; '
                'yerel cüzdanda biriken kısım orada kalır (Bakiyeler sayfasında görünmeye devam eder).', style: const TextStyle(color: Pal.muted, fontSize: 12.5)),
          ],
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 8, children: [
            FilledButton.icon(
              onPressed: !check.ok
                  ? null
                  : () => _apply(() {
                        s.wallet = _wallet.text.trim();
                        s.walletIsLocal = false;
                        if (poolById(s.poolId).payout != Payout.xmr) s.poolId = 'supportxmr';
                      }, 'Kaydedildi.'),
              icon: const Icon(Icons.save),
              label: const Text('Kaydet ve bu adresi kullan'),
            ),
            OutlinedButton.icon(onPressed: () => _open('https://featherwallet.org/download/'), icon: const Icon(Icons.open_in_new, size: 16), label: const Text('Feather Wallet')),
            OutlinedButton.icon(onPressed: () => _open('https://cakewallet.com/'), icon: const Icon(Icons.open_in_new, size: 16), label: const Text('Cake Wallet')),
            OutlinedButton.icon(onPressed: () => _open('https://www.getmonero.org/downloads/'), icon: const Icon(Icons.open_in_new, size: 16), label: const Text('Monero GUI')),
          ]),
        ]),
      ),
      const SizedBox(height: 16),
      _poolPicker(xmrPools),
    ]);
  }

  Widget _poolPicker(List<PoolPreset> list) {
    final app = AppScope.of(context);
    final s = app.settings;
    return Section(
      title: 'XMR havuzu',
      icon: Icons.hub,
      subtitle: 'Hepsi aynı işi yapar; fark ücret, ödeme eşiği ve gecikmedir. Hangisinin daha kârlı olduğunu Kârlılık sayfası canlı olarak sıralar.',
      child: Column(children: [
        for (final p in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                if (p.id == s.poolId) return;
                _apply(() => s.poolId = p.id, '${p.name} seçildi.');
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: p.id == s.poolId ? Pal.orange.withValues(alpha: 0.08) : Pal.surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.id == s.poolId ? Pal.orange : Pal.line),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(p.id == s.poolId ? Icons.radio_button_checked : Icons.radio_button_off, color: p.id == s.poolId ? Pal.orange : Pal.muted, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(p.url, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Consolas', fontSize: 12, color: Pal.muted))),
                        if (p.id != 'custom') Text('ücret %${p.feePct.toStringAsFixed(1)}', style: const TextStyle(fontSize: 12, color: Pal.muted)),
                      ]),
                      const SizedBox(height: 4),
                      Text(p.note, style: const TextStyle(fontSize: 12.5, color: Pal.muted, height: 1.35)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        if (s.poolId == 'custom') ...[
          const SizedBox(height: 4),
          Row(children: [
            Expanded(child: TextField(controller: _custom, decoration: const InputDecoration(labelText: 'sunucu:port'))),
            const SizedBox(width: 12),
            const Text('TLS'),
            Switch(value: s.customTls, onChanged: (v) => s.update(() => s.customTls = v)),
            const SizedBox(width: 8),
            FilledButton(onPressed: () => _apply(() => s.customUrl = _custom.text.trim(), 'Özel havuz kaydedildi.'), child: const Text('Kaydet')),
          ]),
        ],
      ]),
    );
  }

  // ---------------------------------------------------------------- no wallet yet
  Widget _noWallet() {
    final app = AppScope.of(context);
    final s = app.settings;
    final l = _local;
    final active = l != null && s.walletIsLocal && s.wallet == l.address && poolById(s.poolId).payout == Payout.xmr;
    return Column(children: [
      Section(
        title: 'Şimdi kaz, cüzdanı sonra bağla',
        icon: Icons.hourglass_empty,
        trailing: active ? const StatusPill('ETKİN', Pal.ok, icon: Icons.check) : null,
        subtitle: 'Havuzlar ödemeyi mutlaka bir adrese yapar; adressiz kazmak mümkün değildir. Bu yüzden JinjaMine bu bilgisayarda gerçek bir Monero cüzdanı oluşturur ve '
            'kazancı ona yönlendirir. Anahtarlar yalnızca bu bilgisayarda, Windows hesabına bağlı şifreleme (DPAPI) ile saklanır; internete gönderilmez.',
        child: l == null
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _steps([
                  '“Yerel cüzdan oluştur”a bas: adres ve anahtarlar burada üretilir.',
                  'Hemen “Yedeği kaydet” ile anahtarları bir dosyaya al ve güvenli yerde sakla (bilgisayar bozulursa kazanç ancak bu yedekle kurtarılır).',
                  'Kazmaya başla. Kazanç havuzda birikir, eşik dolunca bu cüzdana gelir.',
                  'Sonra: Feather/Cake Wallet’ta “anahtarlardan geri yükle” ile bu cüzdanı aç ve XMR’yi istediğin yere gönder. İstersen o gün kendi adresini de buraya girersin.',
                ]),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () {
                    try {
                      final info = LocalWalletStore.create(restoreHeight: app.market.height);
                      setState(() {
                        _local = info;
                        _showKeys = false;
                      });
                      _apply(() {
                        s.wallet = info.address;
                        s.walletIsLocal = true;
                        if (poolById(s.poolId).payout != Payout.xmr) s.poolId = 'moneroocean';
                      }, 'Yerel cüzdan oluşturuldu. Şimdi yedeği kaydet!');
                    } catch (e) {
                      snack(context, 'Oluşturulamadı: $e', error: true);
                    }
                  },
                  icon: const Icon(Icons.add_card),
                  label: const Text('Yerel cüzdan oluştur'),
                ),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Adres (herkese açık)', style: TextStyle(color: Pal.muted, fontSize: 12)),
                SelectableText(l.address, style: const TextStyle(fontFamily: 'Consolas', fontSize: 12.5)),
                const SizedBox(height: 6),
                Text('Oluşturulma ${l.createdAt.toLocal().toString().substring(0, 16)} · geri yükleme yüksekliği ${l.restoreHeight ?? 'bilinmiyor'}',
                    style: const TextStyle(color: Pal.muted, fontSize: 12)),
                const SizedBox(height: 12),
                Wrap(spacing: 10, runSpacing: 8, children: [
                  if (!active)
                    FilledButton.icon(
                      onPressed: () => _apply(() {
                        s.wallet = l.address;
                        s.walletIsLocal = true;
                        if (poolById(s.poolId).payout != Payout.xmr) s.poolId = 'moneroocean';
                      }, 'Yerel cüzdana kazılıyor.'),
                      icon: const Icon(Icons.check),
                      label: const Text('Bu cüzdana kaz'),
                    ),
                  FilledButton.tonalIcon(onPressed: () => _saveBackup(l), icon: const Icon(Icons.save_alt), label: const Text('Yedeği kaydet')),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _showKeys = !_showKeys),
                    icon: Icon(_showKeys ? Icons.visibility_off : Icons.key),
                    label: Text(_showKeys ? 'Anahtarları gizle' : 'Anahtarları göster'),
                  ),
                ]),
                if (_showKeys) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Pal.bad.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(10), border: Border.all(color: Pal.bad.withValues(alpha: 0.5))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Gizli anahtarlar: bunları gören paraya erişir. Ekran paylaşırken açma.', style: TextStyle(color: Pal.bad, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      const Text('Gizli görüntüleme anahtarı (view key)', style: TextStyle(color: Pal.muted, fontSize: 12)),
                      SelectableText(l.wallet.viewKeyHex, style: const TextStyle(fontFamily: 'Consolas', fontSize: 12)),
                      const SizedBox(height: 6),
                      const Text('Gizli harcama anahtarı (spend key)', style: TextStyle(color: Pal.muted, fontSize: 12)),
                      SelectableText(l.wallet.spendKeyHex, style: const TextStyle(fontFamily: 'Consolas', fontSize: 12)),
                    ]),
                  ),
                ],
              ]),
      ),
      const SizedBox(height: 16),
      Section(
        title: 'Sonra cüzdanı bağlamak ve parayı çekmek',
        icon: Icons.link,
        child: _steps([
          'Feather Wallet’ı kur → “Restore wallet” → “From keys”. Yerel cüzdanın adresini, view key’ini, spend key’ini ve geri yükleme yüksekliğini gir (hepsi yedek dosyasında).',
          'Cüzdan eşitlenince havuzun gönderdiği XMR görünür. Oradan kendi cüzdanına ya da XMR kabul eden bir borsaya/takas servisine gönderebilirsin.',
          'Binance’a geçmek istersen: JinjaMine’da “Binance / borsa” seçeneğini kullan; yeni kazanç doğrudan Binance’a gider. Yerel cüzdandaki XMR’yi Binance XMR almadığı için önce bir takas servisiyle (ör. TRX/LTC’ye) çevirmen gerekir.',
          'Kendi XMR adresin olduğunda “Kendi Monero cüzdanım”dan adresini gir; yeni kazanç oraya gider.',
        ]),
      ),
      const SizedBox(height: 16),
      _poolPicker(pools.where((p) => p.payout == Payout.xmr && !p.advanced).toList()),
    ]);
  }

  Future<void> _saveBackup(LocalWalletInfo l) async {
    final dir = projectDir();
    final f = File('${dir.existsSync() ? dir.path : Platform.environment['USERPROFILE']}\\YEREL_CUZDAN_YEDEK.txt');
    try {
      await f.writeAsString(l.backupText());
      await Process.run('explorer', ['/select,', f.path]);
      if (mounted) snack(context, 'Yedek kaydedildi: ${f.path}. Güvenli bir yere taşı (USB/kâğıt), sonra bu kopyayı sil.');
    } catch (e) {
      if (mounted) snack(context, 'Kaydedilemedi: $e', error: true);
    }
  }

  // ---------------------------------------------------------------- NiceHash
  Widget _niceHash() {
    final s = AppScope.of(context).settings;
    final valid = validBtcAddress(_nh.text);
    final active = s.poolId == 'nicehash';
    return Section(
      title: 'NiceHash',
      icon: Icons.storefront,
      trailing: active ? const StatusPill('ETKİN', Pal.ok, icon: Icons.check) : null,
      subtitle: 'NiceHash’te coin kazmazsın: RandomX gücünü alıcılara satarsın, ödeme BTC olarak NiceHash hesabına gelir; oradan Binance’a çekebilirsin. '
          'Fiyat saatlik değişir; Kârlılık sayfası XMR ile karşılaştırır.',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _steps([
          'nicehash.com’da hesap aç (e-posta + 2FA).',
          'Mining → Mining address (Madencilik adresi) kısmındaki BTC adresini kopyala.',
          'Aşağıya yapıştır ve Kaydet. Panelde “rig” olarak bu bilgisayarın adı görünür.',
        ]),
        _pasteField(_nh, 'NiceHash madencilik adresi (BTC)'),
        const SizedBox(height: 8),
        if (_nh.text.trim().isNotEmpty) _status(valid, valid ? 'BTC adresi biçimi doğru.' : 'Bu bir BTC adresine benzemiyor.'),
        const SizedBox(height: 12),
        Wrap(spacing: 10, children: [
          FilledButton.icon(
            onPressed: !valid
                ? null
                : () => _apply(() {
                      s.nhAddress = _nh.text.trim();
                      s.poolId = 'nicehash';
                    }, 'NiceHash seçildi.'),
            icon: const Icon(Icons.save),
            label: Text(active ? 'Adresi kaydet' : 'Kaydet ve bu yolu kullan'),
          ),
          OutlinedButton.icon(onPressed: () => _open('https://www.nicehash.com/my/mining/rigs'), icon: const Icon(Icons.open_in_new, size: 16), label: const Text('NiceHash paneli')),
        ]),
      ]),
    );
  }
}
