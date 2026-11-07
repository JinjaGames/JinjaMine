# 6. SSS ve sorun giderme

## Sık sorulanlar

**Ekran kartıyla (RTX 5070 Ti) neden kazmıyoruz?**
Ethereum 2022’den beri kazılmıyor. Bugün GPU ile kazılabilen coinlerin (Ravencoin, Ergo, Kaspa vb.) değeri ve/veya
ASIC rekabeti yüzünden 5070 Ti günde birkaç TL kazandırır ve 250–300 W çeker: elektriği karşılamaz.
RandomX’te ise GPU, işlemcinin çok gerisinde kalır. Durum değişirse (yeni bir GPU coin’i kârlı olursa) ayrı bir
motor eklenebilir; şu an eklemek kaynak israfı olur.

**Kazancı artırmanın gerçek yolları?**
1) Huge pages + MSR (yönetici) → +%15–30. 2) Doğru iş parçacığı sayısı (30–32 dene). 3) Eco Mode ile watt başına
verimi artırmak. 4) Bilgisayar zaten açıkken kazmak (boştaki tüketim zaten ödeniyor). 5) Düşük ücretli havuz.

**Bilgisayarı kullanırken kasar mı?**
“Dengeli” hazır ayarında kullanırken yalnızca 8 iş parçacığı ve düşük öncelikle çalışır; oyun açılınca tamamen durur.
Yine de ağır işler (render, derleme) yapacaksan Paneldeki **Duraklat**’ı kullan.

**XMRig’in %1 bağışı nedir?**
Resmî XMRig her 100 dakikanın 1 dakikasını geliştiricilere kazar. Kaynaktan derleyip 0 yapmak mümkündür ama bu
projeyi destekleyen makul bir bedeldir.

**JinjaMine kapalıyken kazmaya devam eder mi?**
Hayır. Pencereyi kapatmak XMRig’i de kapatır. Sürekli kazmak istiyorsan JinjaMine’ı açık bırak (küçült).

## Sorun giderme

| Belirti | Neden / çözüm |
|---|---|
| “xmrig.exe bulunamadı” | Zip’i `Desktop\JinjaMine\xmrig` içine çıkar → *Kurulum → Otomatik bul*. Defender sildiyse 03_KURULUM §3.2. |
| “XMRig başlatılamadı” / hemen kapanıyor | Defender engelliyor olabilir. Günlük sayfasındaki son satırları oku. Exe bozuksa yeniden indir ve SHA-256’yı doğrula. |
| Hız 0, “BAŞLIYOR”da kalıyor | İlk 10–30 sn veri kümesi hazırlanır. 1 dk’dan uzun sürerse Günlük’e bak. “API yanıt vermiyor” uyarısı varsa *Madenci ayarları → Yerel API portu*nu değiştir. |
| Huge pages %0 | JinjaMine’ı yönetici olarak çalıştır, sonra Windows oturumunu kapatıp aç (03_KURULUM §3.3). |
| “MSR kapalı” | Yönetici değil ya da WinRing0 sürücüsü engellendi (bazı Windows sürümlerinde “Savunmasız sürücü engelleme listesi” engeller). MSR’siz de çalışır, ~%5–10 yavaştır. Güvenlik ayarını gevşetmeni önermiyoruz. |
| Çok “rejected” | Saat/ağ sorunu ya da bayat iş. İnternet bağlantını kontrol et; sürekli ise havuzu değiştir. |
| Havuz “adresi tanımıyor” | İlk kabul edilen paydan sonra 5–15 dk içinde görünür. Adresin doğru kaydedildiğini kontrol et. |
| Kazanç sayfası “ağ verisi alınamadı” | xmrchain.net / CoinGecko’ya ulaşılamıyor; birkaç dakika sonra yenile. Madencilik bundan etkilenmez. |
| Bilgisayar çok ısınıyor | *Madenci ayarları → Sessiz* ya da iş parçacığını azalt; BIOS’ta Eco Mode. Sıcaklığı HWiNFO ile izle. |
| Oyun açıkken duraklamıyor | Oyunun exe adını *Madenci ayarları → Oyun açılınca duraklat* listesine ekle (Görev Yöneticisi → Ayrıntılar sekmesinde görünen ad). |

## Teknik notlar (geliştirici için)

- Kaynak: `app\` (Flutter 3.47, Dart). Derleme: `flutter build windows --release --no-tree-shake-icons`, çıktı
  `build\windows\x64\runner\Release` → `dist\JinjaMine`.
- Testler: `dart compile exe tool\fake_xmrig.dart -o build\fake_xmrig.exe` ardından `flutter test`
  (sahte XMRig aynı config/API’yi taklit eder; başlat–izle–duraklat–canlı ayar–durdur akışını sınar).
- Üretilen XMRig ayarı: `%APPDATA%\JinjaMine\config.json`. API: `http://127.0.0.1:<port>/2/summary`,
  `/json_rpc` (pause/resume), `PUT /1/config` (canlı iş parçacığı değişimi), Bearer parola.
