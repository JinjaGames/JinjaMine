# JinjaMine — Flutter kaynak kodu

Windows masaüstü uygulamasının kaynağı. Genel bakış, kurulum ve derleme için [kök README](../README.md)'ye bak.

| Klasör | İçerik |
|---|---|
| `lib/core/` | XMRig süreci ve API'si (`miner.dart`), havuzlar, kârlılık, ayarlar, Monero anahtarları, donanım/sıcaklık |
| `lib/ui/` | Sayfalar ve ortak bileşenler (`widgets.dart`: marka başlığı, kartlar, `appVersion`) |
| `test/` | Birim testleri; `live_test`, `real_xmrig_test` ve `dump_cfg_test` ağ, gerçek XMRig ya da ortam değişkeni ister; varsayılan olarak atlanır |
| `tool/` | `fake_xmrig.dart` (testler için sahte madenci), `make_icon.py` (ikon üretici) |

```bash
flutter pub get
dart compile exe tool/fake_xmrig.dart -o build/fake_xmrig.exe
flutter test
flutter build windows --release --no-tree-shake-icons
```

Ekran görüntüsü almak için uygulama `--page=N` ile belirli bir sayfada açılabilir (0 Panel … 7 Günlük).
