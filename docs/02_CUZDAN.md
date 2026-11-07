# 2. Ödeme: cüzdan, Binance ya da “cüzdan sonra”

Havuzlar kazancı mutlaka **bir adrese** öder; adressiz kazmak mümkün değildir. JinjaMine’da *Cüzdan ve ödeme*
sayfasında dört yol var. Hangisini seçeceğin, parayı sonunda nereye almak istediğine bağlıdır.

| Yol | Ödeme | Ücret | Kimin için |
|---|---|---|---|
| **Kendi Monero cüzdanım** | XMR, kendi cüzdanına | %0–0,9 (havuza göre) | En düşük ücret, tam kontrol. |
| **Binance / borsa** (unMineable) | Seçtiğin coin (TRX, LTC, DOGE, USDT-TRC20, BTC…) doğrudan borsaya | %1 | Binance kullananlar (Binance XMR almaz). |
| **Henüz cüzdanım yok** | XMR, JinjaMine’ın bu bilgisayarda oluşturduğu cüzdana | %0–0,9 | Hemen başlamak, cüzdanı sonra bağlamak isteyenler. |
| **NiceHash hesabı** | BTC, NiceHash hesabına | ~%2 | Gücünü kiraya vermek isteyenler (fiyat saatlik değişir). |

Adres herkese açık bir bilgidir (IBAN gibi). Kurtarma kelimeleri, cüzdan parolası, borsa şifresi **asla**
JinjaMine’a ya da başka bir programa girilmez. JinjaMine bunları hiçbir yolda istemez.

## Binance kullanıyorsan

**Binance, Monero’yu (XMR) Şubat 2024’te listeden çıkardı.** XMR yatırma adresi vermez. Bu yüzden bir XMR havuzunun
ödemesini doğrudan Binance’a gönderemezsin. Çözüm **unMineable** havuzudur:

- Aynı RandomX işini yaparsın.
- Ödemeyi Binance’ın kabul ettiği bir coinle alırsın.

Adımlar:

1. JinjaMine → *Cüzdan ve ödeme* → **Binance / borsa**. Ödeme coinini seç; önerilen **TRX**. Ağ ücreti çok düşüktür,
   unMineable ödeme eşiği 15 TRX’tir (birkaç dolar).
2. Binance uygulaması → **Cüzdan → Yatır (Deposit) → Kripto yatır** → coin olarak **TRX** ara.
3. **Ağ (network): TRON (TRC20)** seç. Yanlış ağ seçilirse para kaybolabilir.
4. Gösterilen adresi kopyala (`T…` ile başlar). JinjaMine’daki alana yapıştır. JinjaMine, adresin o coinin biçimine uyup
   uymadığını kontrol eder.
5. **Kaydet ve bu yolu kullan.** Eşik dolunca ödeme kendiliğinden Binance hesabına düşer.

Notlar:

- **Memo/etiket isteyen coinleri** (XRP, XLM, BNB-BEP2) seçme. unMineable memo gönderemez, para borsada sahipsiz kalır.
- **USDT** seçersen Binance’ta ağ olarak mutlaka **TRC20 (TRON)** seç. Eşiği TRX’ten yüksektir.
- Binance TR ya da başka bir borsa da aynı şekilde çalışır; önemli olan coin ve ağın eşleşmesidir.
- Borsa yatırma adresini yenilerse JinjaMine’daki adresi de güncelle.

## Kendi Monero cüzdanın (en düşük ücret)

| Cüzdan | Nerede | Not |
|---|---|---|
| **Feather Wallet** (önerilen) | Windows / macOS / Linux | Hafif, açık kaynak, tam düğüm indirmez. featherwallet.org |
| **Monero GUI** (resmî) | Windows / macOS / Linux | “Basit mod” uzak düğüm kullanır. getmonero.org/downloads |
| **Cake Wallet** | Android / iOS | Telefonda tutmak istersen. cakewallet.com |

Yalnızca **resmî sitelerden** indir. Arama reklamlarındaki “Monero wallet” sitelerinin bir kısmı sahtedir.

Feather ile cüzdan oluşturmak:

1. Kur, aç → **Create new wallet** → ad ve güçlü parola.
2. Çıkan **kurtarma kelimelerini** (16 ya da 25 kelime) kâğıda yaz, iki kopya, ayrı yerlerde sakla.
   Fotoğraf çekme, buluta yazma, kimseyle paylaşma.
3. **Receive** sekmesindeki `4…` ile başlayan adresi kopyala.
4. JinjaMine → *Kendi Monero cüzdanım* → yapıştır → **Kaydet**.
   JinjaMine adresin **sağlama toplamını** da doğrular; tek harf yanlış kopyalanırsa uyarır.

## Henüz cüzdanın yoksa: “şimdi kaz, sonra bağla”

1. JinjaMine → **Henüz cüzdanım yok** → **Yerel cüzdan oluştur**.
   - JinjaMine bu bilgisayarda standart bir Monero cüzdanı üretir: adres, gizli görüntüleme anahtarı ve gizli harcama anahtarı.
   - Anahtarlar internete gönderilmez. `%APPDATA%\JinjaMine\yerel_cuzdan.bin` dosyasında **Windows DPAPI** ile
     şifrelenir; yalnızca bu Windows kullanıcısı çözebilir.
2. **Hemen “Yedeği kaydet”.** `Desktop\JinjaMine\YEREL_CUZDAN_YEDEK.txt` oluşur.
   - Bilgisayar bozulursa ya da Windows yeniden kurulursa kazanç **yalnızca bu yedekle** kurtarılır.
   - Yedeği USB’ye ya da kâğıda al, sonra masaüstündeki kopyayı sil.
3. Kazmaya başla. Kazanç havuzda birikir, eşik dolunca bu cüzdana gelir. *Bakiyeler* sayfasında görünür.

Sonra parayı çekmek:

- **Feather → Restore wallet → From keys:** adres, view key, spend key ve geri yükleme yüksekliğini gir.
  Hepsi yedek dosyasında. Cüzdan eşitlenince XMR görünür ve istediğin yere gönderebilirsin.
- **Kendi XMR adresin olunca:** *Kendi Monero cüzdanım*a gir. Yeni kazanç oraya gider; yerel cüzdanda biriken
  kısım orada kalır ve *Bakiyeler*’de listelenmeye devam eder.
- **Binance’a geçmek istersen:** *Binance / borsa* yolunu seç; yeni kazanç doğrudan Binance’a gider.
  Yerel cüzdandaki XMR’yi Binance almadığı için önce bir takas servisiyle (ör. TRX/LTC’ye) çevirmek gerekir.

## NiceHash

NiceHash’te coin kazmazsın, RandomX gücünü kiraya verirsin.

- Ödeme BTC olarak NiceHash hesabına gelir; oradan Binance’a çekilebilir.
- Hesap gerekir: e-posta ve 2FA. Mining → *Mining address* kısmındaki BTC adresini JinjaMine’a gir.
- **Fiyat uyarısı:** WhatToMine ile NiceHash’in kendi API’si şu an aynı saat için yaklaşık 10 kat farklı fiyat gösteriyor.
  Bu yüzden JinjaMine NiceHash’i “tahmin belirsiz” olarak listeler; önermez ve otomatik geçişte seçmez.
  Kullanmadan önce NiceHash’in kendi kârlılık hesaplayıcısıyla doğrula.

## TL’ye çevirmek

- XMR birçok büyük borsada listeden kaldırıldı. Satmak için XMR’yi hâlâ listeleyen bir borsaya ya da güvenilir bir
  takas servisine göndermek gerekir.
- Binance yolunu (TRX/LTC/USDT) seçtiysen kazanç zaten borsadadır; doğrudan TL’ye çevrilebilir.
- Vergi tarafı için 05_GUVENLIK_VE_YASAL.md’ye bak.
