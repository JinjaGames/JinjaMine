import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/miner.dart';
import '../core/settings.dart';
import '../core/system.dart';
import 'theme.dart';
import 'widgets.dart';

class MinerSettingsPage extends StatefulWidget {
  const MinerSettingsPage({super.key});
  @override
  State<MinerSettingsPage> createState() => _MinerSettingsPageState();
}

class _MinerSettingsPageState extends State<MinerSettingsPage> {
  final _game = TextEditingController();
  bool? _autostart;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    autostartEnabled().then((v) => mounted ? setState(() => _autostart = v) : null);
  }

  void _set(void Function() f) {
    AppScope.of(context).settings.update(f);
    if (AppScope.of(context).miner.busy) setState(() => _dirty = true);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.settings, m = app.miner, hw = app.hardware;
    final n = Platform.numberOfProcessors;
    return ListenableBuilder(
      listenable: Listenable.merge([s, m, hw]),
      builder: (context, _) => ListView(padding: const EdgeInsets.all(20), children: [
        if (_dirty && m.busy) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Pal.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Pal.blue.withValues(alpha: 0.5))),
            child: Row(children: [
              const Icon(Icons.info_outline, color: Pal.blue),
              const SizedBox(width: 10),
              const Expanded(child: Text('Ayarlar değişti. Çalışan madenciye uygulamak için:')),
              FilledButton(
                onPressed: () async {
                  await m.applyLive();
                  setState(() => _dirty = false);
                },
                child: const Text('Canlı uygula'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () async {
                  await m.restart();
                  setState(() => _dirty = false);
                },
                child: const Text('Yeniden başlat'),
              ),
            ]),
          ),
          const SizedBox(height: 16),
        ],
        Section(
          title: 'Hazır ayarlar',
          icon: Icons.auto_awesome,
          subtitle: 'Birine tıkla; aşağıdaki değerler dolar. Bu bilgisayarda (7950X) ölçüm: 16 iş parçacığı ~7,8 kH/s, 24 ~9,8 kH/s, 32 ~8,6 kH/s (huge pages kapalıyken). İş parçacıkları önce her fiziksel çekirdeğe birer tane yerleştirilir.',
          child: Wrap(spacing: 10, runSpacing: 10, children: [
            _preset(Icons.volume_off, 'Sessiz', 'Çekirdeklerin dörtte biri, en düşük öncelik. Bilgisayarı rahatça kullanırsın.', () {
              s.mode = RunMode.always;
              s.threads = max(1, n ~/ 4);
              s.priority = 0;
            }),
            _preset(Icons.balance, 'Dengeli', 'Kullanırken hafif, boştayken tam güç (uyarlamalı).', () {
              s.mode = RunMode.adaptive;
              s.activeThreads = max(1, n ~/ 4);
              s.idleThreads = max(1, n * 3 ~/ 4);
              s.idleMinutes = 3;
              s.priority = 1;
            }),
            _preset(Icons.local_fire_department, 'Tam güç', 'Bilgisayar yalnızca kazıyorsa. Ölçülen en iyi sayı (24).', () {
              s.mode = RunMode.always;
              s.threads = max(1, n * 3 ~/ 4);
              s.priority = 2;
            }),
            _preset(Icons.bedtime, 'Gece', 'Yalnızca 5 dk boşta kalınca başlar, dokununca durur.', () {
              s.mode = RunMode.idleOnly;
              s.idleThreads = max(1, n * 3 ~/ 4);
              s.idleMinutes = 5;
              s.priority = 1;
            }),
          ]),
        ),
        const SizedBox(height: 16),
        _tuneCard(m),
        const SizedBox(height: 16),
        Section(
          title: 'Çalışma biçimi',
          icon: Icons.schedule,
          trailing: Wrap(spacing: 6, children: [
            TempChip(label: 'CPU', reading: hw.cpu),
            if (hw.gpuName != null) TempChip(label: 'GPU', reading: hw.gpu),
          ]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SegmentedButton<RunMode>(
              showSelectedIcon: false,
              segments: [for (final r in RunMode.values) ButtonSegment(value: r, label: Text(r.title))],
              selected: {s.mode},
              onSelectionChanged: (v) => _set(() => s.mode = v.first),
            ),
            const SizedBox(height: 6),
            Text(s.mode.help, style: const TextStyle(color: Pal.muted, fontSize: 12.5)),
            const SizedBox(height: 8),
            if (s.mode == RunMode.always)
              SliderTile(
                label: 'İş parçacığı sayısı',
                value: s.threads.toDouble(),
                min: 1,
                max: n.toDouble(),
                divisions: n - 1,
                display: '${s.threads} / $n',
                onChanged: (v) => _set(() => s.threads = v.round()),
                help: 'Her iş parçacığı bir mantıksal çekirdek kullanır ve ~2 MB L3 önbellek ister.',
              ),
            if (s.mode != RunMode.always) ...[
              SliderTile(
                label: 'Boştayken iş parçacığı',
                value: s.idleThreads.toDouble(),
                min: 1,
                max: n.toDouble(),
                divisions: n - 1,
                display: '${s.idleThreads} / $n',
                onChanged: (v) => _set(() => s.idleThreads = v.round()),
              ),
              if (s.mode == RunMode.adaptive)
                SliderTile(
                  label: 'Kullanırken iş parçacığı',
                  value: s.activeThreads.toDouble(),
                  min: 1,
                  max: n.toDouble(),
                  divisions: n - 1,
                  display: '${s.activeThreads} / $n',
                  onChanged: (v) => _set(() => s.activeThreads = v.round()),
                ),
              SliderTile(
                label: 'Boşta sayılma süresi',
                value: s.idleMinutes.toDouble(),
                min: 1,
                max: 30,
                divisions: 29,
                display: '${s.idleMinutes} dk',
                onChanged: (v) => _set(() => s.idleMinutes = v.round()),
                help: 'Bu kadar süre klavye ve fareye dokunulmazsa bilgisayar “boşta” sayılır.',
              ),
            ],
            SliderTile(
              label: 'İşlem önceliği',
              value: s.priority.toDouble(),
              min: 0,
              max: 5,
              divisions: 5,
              display: const ['boşta', 'düşük', 'normal', 'normalin üstü', 'yüksek', 'en yüksek'][s.priority],
              onChanged: (v) => _set(() => s.priority = v.round()),
              help: 'Düşük öncelik, sen bir şey yaptığında Windows’un işlemciyi önce sana vermesini sağlar. 0–1 önerilir.',
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Section(
          title: 'Sıcaklık koruması',
          icon: Icons.device_thermostat,
          trailing: TempChip(label: 'CPU', reading: hw.cpu),
          subtitle: 'İşlemci sınırı 20 saniye aşarsa iş parçacığı %25 azaltılır (gerekirse tekrar); sınırın 8 °C altına inip 2 dakika öyle kalınca kademeli geri artırılır. '
              'Ekran kartı sınırı aşınca uyarı verilir (JinjaMine ekran kartıyla kazmaz). Renkler: mavi serin · yeşil normal · sarı sınıra 10 °C kala · kırmızı sınırın üstü.',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: s.tempGuard,
              onChanged: (v) => s.update(() => s.tempGuard = v),
              title: const Text('Etkin'),
              subtitle: Text(hw.cpuTemp == null
                  ? 'İşlemci sıcaklığı şu an okunamıyor; koruma, sıcaklık okunabildiğinde devreye girer (Kurulum → LibreHardwareMonitor).'
                  : 'Şu an ${hw.cpuTemp!.toStringAsFixed(0)} °C (${hw.cpuSource}).'),
            ),
            SliderTile(
              label: 'İşlemci sınırı',
              value: s.cpuTempLimit.toDouble(),
              min: 60,
              max: 95,
              divisions: 35,
              display: '${s.cpuTempLimit} °C',
              onChanged: (v) => s.update(() => s.cpuTempLimit = v.round()),
              help: 'Ryzen 7000 serisi 95 °C’ye kadar kendini korur ve tam yükte oraya çıkabilir; uzun süreli madencilik için 85–90 °C daha sessiz ve dayanıklıdır.',
            ),
            SliderTile(
              label: 'Ekran kartı uyarı sınırı',
              value: s.gpuTempLimit.toDouble(),
              min: 60,
              max: 90,
              divisions: 30,
              display: '${s.gpuTempLimit} °C',
              onChanged: (v) => s.update(() => s.gpuTempLimit = v.round()),
              help: 'RTX 50 serisi ~88 °C’de kendini yavaşlatır; 83 °C üstü uzun süre istenmez.',
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Section(
          title: 'Kâr koruması',
          icon: Icons.savings,
          subtitle: 'Kazanç sayfasındaki elektrik fiyatı ve ek güç ile hesaplanan net sonuç eksiye düşerse (elektrik kazançtan pahalıysa) madenci duraklar, '
              'artıya dönünce devam eder. Fiyat 30 dakikada bir yenilenir.',
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: s.profitGuard,
            onChanged: (v) => s.update(() => s.profitGuard = v),
            title: const Text('Zararına kazma'),
            subtitle: Builder(builder: (context) {
              final o = AppScope.of(context).profit.optionFor(s.poolId);
              return Text(o == null || o.grossTry <= 0 ? 'Henüz hesaplanmadı.' : 'Şu anki yol: günde ${tl(o.netTry)} TL net (${o.netTry >= 0 ? 'kârda' : 'zararda'}).');
            }),
          ),
        ),
        const SizedBox(height: 16),
        Section(
          title: 'Oyun açılınca duraklat',
          icon: Icons.sports_esports,
          subtitle: 'Listedeki programlardan biri çalışırken madenci duraklar, kapanınca devam eder. 5 saniyede bir kontrol edilir.',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: s.pauseOnGames,
              onChanged: (v) => _set(() => s.pauseOnGames = v),
              title: const Text('Etkin'),
            ),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final g in s.gameExes)
                InputChip(label: Text(g), onDeleted: () => _set(() => s.gameExes = [...s.gameExes]..remove(g))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              SizedBox(
                width: 280,
                child: TextField(controller: _game, decoration: const InputDecoration(labelText: 'Program adı ekle (ör. GTA5.exe)')),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () {
                  final t = _game.text.trim();
                  if (t.isEmpty) return;
                  _set(() => s.gameExes = [...s.gameExes, t.toLowerCase().endsWith('.exe') ? t : '$t.exe']);
                  _game.clear();
                },
                child: const Text('Ekle'),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        Section(
          title: 'Performans (ileri)',
          icon: Icons.tune,
          subtitle: 'Bunlar XMRig’in kendi ayarlarıdır. Huge pages ve MSR yönetici izniyle çalışır; Ryzen’de birlikte ~%15–30 hız kazandırır.',
          child: Column(children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: s.hugePages,
              onChanged: (v) => _set(() => s.hugePages = v),
              title: const Text('Huge pages (büyük bellek sayfaları)'),
              subtitle: const Text('İlk kez yönetici olarak çalışınca Windows “Bellekte sayfaları kilitle” iznini verir; etkinleşmesi için oturumu kapatıp açmak ya da yeniden başlatmak gerekir.'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: s.oneGbPages,
              onChanged: (v) => _set(() => s.oneGbPages = v),
              title: const Text('1 GB sayfalar'),
              subtitle: const Text('Windows’ta desteklenmez (yalnız Linux). Kapalı kalmalı; burada sadece tamlık için var.'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: s.msr,
              onChanged: (v) => _set(() => s.msr = v),
              title: const Text('MSR ayarı (Ryzen önbellek ön-getirme)'),
              subtitle: const Text('XMRig, işlemcinin önbellek ayarlarını madencilik süresince değiştirir (yönetici + WinRing0 sürücüsü gerekir). Madenci kapanınca eski hâline döner.'),
            ),
            SliderTile(
              label: 'XMRig geliştirici bağışı',
              value: s.donateLevel.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              display: '%${s.donateLevel}',
              onChanged: (v) => _set(() => s.donateLevel = v.round()),
              help: 'XMRig her 100 dakikanın bu kadarını geliştiricilere kazar. Resmî sürümde en az %1’dir.',
            ),
            SliderTile(
              label: 'Yerel API portu',
              value: s.apiPort.toDouble(),
              min: 18000,
              max: 18200,
              divisions: 200,
              display: '${s.apiPort}',
              onChanged: (v) => _set(() => s.apiPort = v.round()),
              help: 'Uygulama XMRig’i yalnızca 127.0.0.1 üzerinden ve rastgele bir parolayla izler; dışarıya açık değildir.',
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Section(
          title: 'Açılış',
          icon: Icons.power_settings_new,
          child: Column(children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: s.startMiningOnLaunch,
              onChanged: (v) => _set(() => s.startMiningOnLaunch = v),
              title: const Text('JinjaMine açılınca madenciliği kendiliğinden başlat'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _autostart ?? false,
              onChanged: _autostart == null
                  ? null
                  : (v) async {
                      await setAutostart(v);
                      final now = await autostartEnabled();
                      if (mounted) setState(() => _autostart = now);
                    },
              title: const Text('Windows açılınca JinjaMine’ı başlat'),
              subtitle: const Text('Kullanıcı başlangıç listesine (HKCU\\…\\Run) eklenir; kapatınca silinir.'),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _tuneCard(MinerController m) {
    final t = m.tune;
    final running = t != null && !t.done;
    return Section(
      title: 'Otomatik hız ayarı',
      icon: Icons.auto_graph,
      subtitle: 'En iyi iş parçacığı sayısı işlemciye, belleğe, huge pages durumuna ve sıcaklığa göre değişir. Madenci çalışırken birkaç sayıyı canlı dener '
          '(her biri ~55 sn, yeniden başlatma yok) ve en hızlısını kaydeder. Huge pages’i ya da yönetici iznini değiştirdikten sonra tekrar çalıştır.',
      trailing: running
          ? OutlinedButton.icon(onPressed: m.cancelTune, icon: const Icon(Icons.close), label: const Text('İptal'))
          : FilledButton.icon(
              onPressed: m.state == MinerState.running ? m.autoTune : null,
              icon: const Icon(Icons.play_arrow),
              label: Text(m.state == MinerState.running ? 'Başlat' : 'Önce madenciyi başlat'),
            ),
      child: t == null
          ? const Text('Henüz çalıştırılmadı.', style: TextStyle(color: Pal.muted))
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (running) ...[
                LinearProgressIndicator(value: t.progress, minHeight: 6, borderRadius: BorderRadius.circular(3)),
                const SizedBox(height: 6),
                Text('Deneniyor: ${t.current} iş parçacığı (${t.tried + 1}/${t.candidates.length})', style: const TextStyle(color: Pal.amber)),
                const SizedBox(height: 8),
              ],
              Wrap(spacing: 10, runSpacing: 8, children: [
                for (final c in t.candidates)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: t.best == c ? Pal.ok.withValues(alpha: 0.12) : Pal.surface2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: t.best == c ? Pal.ok : (running && t.current == c ? Pal.amber : Pal.line)),
                    ),
                    child: Column(children: [
                      Text('$c', style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(t.results[c] == null ? (running && t.current == c ? 'ölçülüyor' : '—') : humanHash(t.results[c]!), style: const TextStyle(color: Pal.muted, fontSize: 12)),
                    ]),
                  ),
              ]),
              if (t.best != null) ...[
                const SizedBox(height: 8),
                Text('En hızlısı ${t.best} iş parçacığı; “İş parçacığı sayısı” buna ayarlandı.', style: const TextStyle(color: Pal.ok)),
              ],
            ]),
    );
  }

  Widget _preset(IconData icon, String name, String text, void Function() apply) => Tooltip(
        message: text,
        child: ActionChip(
          avatar: Icon(icon, size: 18, color: Pal.orange),
          label: Text(name),
          onPressed: () {
            _set(apply);
            snack(context, '“$name” uygulandı.');
          },
        ),
      );
}
