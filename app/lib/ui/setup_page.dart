import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/system.dart';
import '../core/wallet.dart';
import 'theme.dart';
import 'widgets.dart';

class SetupPage extends StatefulWidget {
  const SetupPage({super.key});
  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  late final TextEditingController _path;
  bool _inited = false;
  bool? _admin;
  String? _sha;
  bool _hashing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;
    _inited = true;
    final s = AppScope.of(context).settings;
    if (s.xmrigPath.isEmpty || !File(s.xmrigPath).existsSync()) {
      final f = findXmrig();
      if (f != null) s.update(() => s.xmrigPath = f);
    }
    _path = TextEditingController(text: s.xmrigPath);
    isElevated().then((v) => mounted ? setState(() => _admin = v) : null);
  }

  Future<void> _open(String url) async {
    if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication) && mounted) snack(context, 'Açılamadı: $url', error: true);
  }

  String get _mineDir => projectDir().path;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.settings, m = app.miner;
    return ListenableBuilder(
      listenable: Listenable.merge([s, m]),
      builder: (context, _) {
        final walletOk = !m.problems().any((p) => p.startsWith('Cüzdan'));
        final xmrigOk = s.xmrigPath.isNotEmpty && File(s.xmrigPath).existsSync();
        final hp = m.summary?.hugePages;
        final hpOk = hp != null && hp[1] > 0 && hp[0] == hp[1];
        return ListView(padding: const EdgeInsets.all(20), children: [
          Section(
            title: 'Kurulum rehberi',
            icon: Icons.checklist,
            subtitle: 'Sırayla yeşil olması gerekenler. Ayrıntılar belgelerde ($_mineDir\\docs).',
            child: Column(children: [
              CheckRow(AppScope.of(context).hardware.cpuTemp != null, 'İşlemci sıcaklığı okunuyor (isteğe bağlı)',
                  warn: true,
                  detail: AppScope.of(context).hardware.cpuTemp != null
                      ? 'Kaynak: ${AppScope.of(context).hardware.cpuSource}'
                      : 'Windows, Ryzen sıcaklığını sürücüsüz vermez. LibreHardwareMonitor’ı (ücretsiz, açık kaynak) indirip yönetici olarak aç ve açık bırak; '
                          'Options → Remote Web Server → Run seçersen JinjaMine sıcaklığı oradan da okur. Sıcaklık koruması bu sayede çalışır.'),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _open('https://github.com/LibreHardwareMonitor/LibreHardwareMonitor/releases'),
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: const Text('LibreHardwareMonitor (GitHub sürümleri)'),
                ),
              ),
              CheckRow(walletOk, 'Ödeme adresi girildi',
                  detail: walletOk
                      ? '${s.payoutCoinOf()} → ${shortAddress(s.payoutAddress())}${s.walletIsLocal && s.payoutCoinOf() == 'XMR' ? ' (bu bilgisayarda oluşturulan yerel cüzdan — yedeğini aldın mı?)' : ''}'
                      : '“Cüzdan ve ödeme” sayfasında seç: Binance/borsa, kendi XMR cüzdanın ya da “henüz cüzdanım yok” (yerel cüzdan).'),
              CheckRow(xmrigOk, 'XMRig indirildi', detail: xmrigOk ? s.xmrigPath : 'Aşağıdaki “Resmî indirme sayfası”ndan xmrig-…-windows-x64.zip indir, $_mineDir\\xmrig klasörüne çıkar.'),
              CheckRow(_admin == true, 'JinjaMine yönetici olarak çalışıyor', warn: _admin == false,
                  detail: _admin == true ? 'Huge pages ve MSR kullanılabilir.' : 'İsteğe bağlı ama ~%15–30 daha hızlı. Aşağıdaki düğme UAC sorusuyla yeniden açar.'),
              CheckRow(hpOk, 'Huge pages etkin', warn: hp != null && !hpOk,
                  detail: hp == null
                      ? 'Madenci çalışınca kontrol edilir.'
                      : hpOk
                          ? '${hp[0]}/${hp[1]} sayfa ayrıldı.'
                          : '${hp[0]}/${hp[1]}. Yönetici olarak bir kez çalıştır, sonra Windows oturumunu kapatıp aç.'),
              CheckRow(m.summary != null && m.summary!.accepted > 0, 'Havuz ilk payı kabul etti',
                  detail: m.summary == null ? 'Panelden “Kazmaya başla”.' : '${m.summary!.accepted} kabul, ${m.summary!.rejected} red.'),
            ]),
          ),
          const SizedBox(height: 16),
          Section(
            title: 'XMRig (madencilik motoru)',
            icon: Icons.memory,
            subtitle: 'XMRig, Monero için en yaygın açık kaynak madencilik programıdır. JinjaMine onu başlatır, ayarlar ve izler. Yalnızca resmî GitHub sayfasından indir; '
                'başka sitelerdeki “hızlandırılmış” sürümler genelde virüslüdür.',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(
                controller: _path,
                style: const TextStyle(fontFamily: 'Consolas', fontSize: 13),
                decoration: const InputDecoration(labelText: 'xmrig.exe yolu'),
                onSubmitted: (v) => s.update(() => s.xmrigPath = v.trim().replaceAll('"', '')),
              ),
              const SizedBox(height: 10),
              Wrap(spacing: 10, runSpacing: 8, children: [
                FilledButton.icon(
                  onPressed: () {
                    s.update(() => s.xmrigPath = _path.text.trim().replaceAll('"', ''));
                    setState(() => _sha = null);
                    snack(context, File(s.xmrigPath).existsSync() ? 'Kaydedildi.' : 'Bu yolda dosya yok.', error: !File(s.xmrigPath).existsSync());
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Kaydet'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    final f = findXmrig();
                    if (f == null) return snack(context, 'Bulunamadı. Zip’i $_mineDir\\xmrig içine çıkar.', error: true);
                    _path.text = f;
                    s.update(() => s.xmrigPath = f);
                    snack(context, 'Bulundu: $f');
                  },
                  icon: const Icon(Icons.search),
                  label: const Text('Otomatik bul'),
                ),
                OutlinedButton.icon(onPressed: () => _open('https://github.com/xmrig/xmrig/releases/latest'), icon: const Icon(Icons.open_in_new, size: 16), label: const Text('Resmî indirme sayfası')),
                OutlinedButton.icon(
                  onPressed: () {
                    final d = Directory('$_mineDir\\xmrig');
                    if (!d.existsSync()) d.createSync(recursive: true);
                    Process.run('explorer', [d.path]);
                  },
                  icon: const Icon(Icons.folder_open, size: 16),
                  label: const Text('xmrig klasörünü aç'),
                ),
                OutlinedButton.icon(
                  onPressed: !xmrigOk || _hashing
                      ? null
                      : () async {
                          setState(() => _hashing = true);
                          final h = await m.sha256Of(s.xmrigPath);
                          if (mounted) setState(() => (_sha = h, _hashing = false));
                        },
                  icon: const Icon(Icons.fingerprint, size: 16),
                  label: const Text('SHA-256 hesapla'),
                ),
              ]),
              if (_sha != null) ...[
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: SelectableText('SHA-256: $_sha', style: const TextStyle(fontFamily: 'Consolas', fontSize: 12.5))),
                  IconButton(tooltip: 'Kopyala', icon: const Icon(Icons.copy, size: 16), onPressed: () => Clipboard.setData(ClipboardData(text: _sha!))),
                ]),
                const Text('Asıl doğrulama ZIP üzerinde yapılır: indirme sayfasındaki SHA256SUMS dosyası ZIP’lerin özetini verir. '
                    'PowerShell’de  Get-FileHash .\\xmrig-<sürüm>-windows-x64.zip  çalıştırıp çıkan değeri o listedeki satırla karşılaştır. '
                    'Yukarıdaki değer, çıkardığın xmrig.exe’nin sonradan değişmediğini izlemek için kaydedebileceğin özettir.',
                    style: TextStyle(color: Pal.muted, fontSize: 12, height: 1.35)),
              ],
            ]),
          ),
          const SizedBox(height: 16),
          Section(
            title: 'Antivirüs',
            icon: Icons.shield_outlined,
            subtitle: 'Windows Defender, XMRig’i (resmî olsa bile) “potansiyel istenmeyen uygulama / CoinMiner” diye işaretleyip silebilir; çünkü kötü amaçlı yazılımlar da gizlice aynı programı kurar. '
                'Kendi isteğinle, kendi bilgisayarında, resmî sürümü çalıştırdığında bu bir yanlış alarm sayılır.',
            child: Text(
              'Çözüm (bunu sen yaparsın, uygulama güvenlik ayarlarını değiştirmez):\n'
              '1) Windows Güvenliği → Virüs ve tehdit koruması → Ayarları yönet → Dışlamalar → Dışlama ekle → Klasör.\n'
              '2) Yalnızca $_mineDir\\xmrig klasörünü seç (bütün diski ya da Masaüstü’nü değil).\n'
              '3) Defender zip’i zaten sildiyse: Koruma geçmişi → ilgili kayıt → “Cihazda izin ver”, sonra zip’i yeniden çıkar.',
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
          ),
          const SizedBox(height: 16),
          Section(
            title: 'Yönetici izni',
            icon: Icons.admin_panel_settings,
            child: Row(children: [
              Expanded(
                child: Text(
                  _admin == null
                      ? 'Kontrol ediliyor…'
                      : _admin!
                          ? 'JinjaMine yönetici olarak çalışıyor. XMRig de bu izni devralır.'
                          : 'JinjaMine normal kullanıcı olarak çalışıyor. Huge pages / MSR için yönetici olarak yeniden aç.',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              if (_admin == false)
                FilledButton.icon(
                  onPressed: () async {
                    if (m.busy) await m.stop();
                    final ok = await relaunchElevated();
                    if (ok) {
                      exit(0);
                    } else if (context.mounted) {
                      snack(context, 'Yönetici izni verilmedi.', error: true);
                    }
                  },
                  icon: const Icon(Icons.shield),
                  label: const Text('Yönetici olarak yeniden başlat'),
                ),
            ]),
          ),
          const SizedBox(height: 16),
          Section(
            title: 'Belgeler',
            icon: Icons.menu_book,
            child: Wrap(spacing: 10, runSpacing: 8, children: [
              for (final f in const [
                'README.md',
                'SISTEM.md',
                'docs\\01_GERCEKCI_BEKLENTI.md',
                'docs\\02_CUZDAN.md',
                'docs\\03_KURULUM.md',
                'docs\\04_HAVUZLAR.md',
                'docs\\05_GUVENLIK_VE_YASAL.md',
                'docs\\06_SSS_SORUN_GIDERME.md',
              ])
                OutlinedButton.icon(
                  onPressed: () {
                    final p = '$_mineDir\\$f';
                    if (File(p).existsSync()) {
                      Process.run('cmd', ['/c', 'start', '', p]);
                    } else {
                      snack(context, 'Bulunamadı: $p', error: true);
                    }
                  },
                  icon: const Icon(Icons.description, size: 16),
                  label: Text(f.replaceAll('docs\\', '')),
                ),
            ]),
          ),
        ]);
      },
    );
  }
}
