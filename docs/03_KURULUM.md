# 3. Kurulum

## 3.1 XMRig’i indir

XMRig, Monero için en yaygın açık kaynak madencilik programıdır (GPL-3.0). JinjaMine bir “ön yüz”dür: XMRig’i başlatır,
ayarlar ve izler.

1. **Yalnızca resmî adres:** https://github.com/xmrig/xmrig/releases/latest
   (xmrig.com da resmîdir ve aynı GitHub sürümlerine yönlendirir.)
2. Listeden `xmrig-<sürüm>-windows-x64.zip` dosyasını indir (`gcc-win64` ya da `msvc-win64` — ikisi de olur).
3. **Doğrula (önerilir):** aynı sayfadaki `SHA256SUMS` dosyasını aç. PowerShell’de:
   ```powershell
   Get-FileHash $env:USERPROFILE\Downloads\xmrig-*-windows-x64.zip
   ```
   Çıkan değer, SHA256SUMS’taki o zip’in satırıyla **birebir** aynı olmalı. Değilse dosyayı sil.
4. Zip’i `Desktop\JinjaMine\xmrig\` klasörüne çıkar (JinjaMine’da *Kurulum → xmrig klasörünü aç*).
   İçinde `xmrig.exe` olmalı (alt klasörde olması da sorun değil).
5. JinjaMine → *Kurulum* → **Otomatik bul**. Yol dolar ve kontrol listesinde “XMRig indirildi” yeşil olur.

## 3.2 Antivirüs (Windows Defender)

Defender, resmî XMRig’i bile işaretleyip engeller (bu bilgisayarda v6.26.0 için verdiği ad: **“Trojan:Win64/HashvaultMiner.A”**, önem: Ciddi); çünkü virüsler de aynı programı
kurbanın bilgisayarına gizlice kurar. Kendi isteğinle, kendi bilgisayarında resmî sürümü çalıştırmak bu açıdan
yanlış alarmdır. Çözüm **senin elinde** (JinjaMine güvenlik ayarlarına dokunmaz):

1. *Windows Güvenliği* → *Virüs ve tehdit koruması* → *Virüs ve tehdit koruması ayarları* → *Ayarları yönet*.
2. Aşağıda *Dışlamalar* → *Dışlama ekle veya kaldır* → *Dışlama ekle* → **Klasör**.
3. **Yalnızca** `C:\Users\user\Desktop\JinjaMine\xmrig` klasörünü seç. Masaüstünün ya da diskin tamamını değil.
4. Zip zaten silindiyse: *Koruma geçmişi* → ilgili kayıt → *Eylemler* → *Cihazda izin ver*, sonra yeniden çıkar.

## 3.3 Yönetici izni, huge pages ve MSR (isteğe bağlı, ~%15–30 hız)

- **Huge pages:** RandomX’in belleği 2 MB’lık büyük sayfalarla kullanması. Windows’ta “Bellekte sayfaları kilitle”
  hakkı gerekir. XMRig yönetici olarak ilk çalıştığında bu hakkı hesabına kendisi ekler.
- **MSR:** Ryzen’in önbellek ön-getirme ayarlarını madencilik süresince RandomX’e uygun hâle getirir
  (WinRing0 sürücüsüyle, yönetici gerekir). Madenci kapanınca ayarlar eski hâline döner.

Yapılışı:
1. JinjaMine → *Kurulum* → **Yönetici olarak yeniden başlat** (UAC sorusuna *Evet*).
2. *Panel* → **Kazmaya başla**, bir dakika çalıştır, durdur.
3. Windows’ta **oturumu kapatıp aç** (ya da yeniden başlat) — hak ancak yeni oturumda geçerli olur.
4. JinjaMine’ı yine yönetici olarak aç ve başlat. *Panel*’de “Huge pages **100 %**” ve “MSR açık” görmelisin.

Yönetici izni vermek istemezsen JinjaMine normal kullanıcıyla da kazar; yalnızca daha yavaştır.

## 3.4 İlk çalıştırma

1. `Desktop\JinjaMine\dist\JinjaMine\JinjaMine.exe` (SmartScreen uyarısında *Ek bilgi → Yine de çalıştır*; imzasız olduğu için normal).
2. *Cüzdan ve ödeme*: ödeme yolunu seç, adresi gir → **Kaydet**. Havuzu *Kârlılık* sayfasındaki öneriye göre seç (bugün MoneroOcean).
3. *Madenci ayarları*: bir hazır ayar seç (**Dengeli** önerilir).
4. *Panel* → **Kazmaya başla**.
   - 10–30 sn: RandomX veri kümesi hazırlanır (hız 0 görünür, normal).
   - Sonra hız yükselir; birkaç dakika içinde “Kabul edilen pay” artar.
   - 15–30 dk sonra havuz da seni görür (*Bakiyeler* sayfası).
5. Havuz panelinde (SupportXMR → adresinle giriş) ödeme eşiğini **0,003 XMR** gibi düşük bir değere ayarlayabilirsin.

## 3.5 Kaldırma

- *Madenci ayarları → Açılış* → “Windows açılınca başlat”ı kapat (başlangıç kaydını siler).
- `Desktop\JinjaMine` klasörünü sil. Ayarlar `%APPDATA%\com.jinjagames\JinjaMine` ve `%APPDATA%\JinjaMine` içindedir; onları da silebilirsin.
- Defender dışlamasını kaldır (3.2’deki ekrandan).
