# 1. Gerçekçi beklenti: ne kadar kazanılır?

## Bugünkü değerler (2026-11-04, canlı okundu)

| Veri | Değer | Kaynak |
|---|---|---|
| Monero ağ hızı | ~7,3–7,4 GH/s | xmrchain.net |
| Ağ zorluğu | ~875–884 milyar | xmrchain.net |
| Blok ödülü | ~0,60 XMR + işlem ücretleri (~0,60–0,65) | son bloğun coinbase’i |
| Blok süresi | 2 dakika (günde 720 blok) | protokol |
| XMR fiyatı | ~640 $ ≈ **32.000 TL** | CoinGecko |

## Formül

```
günlük XMR = senin_hızın × 86400 / ağ_zorluğu × blok_ödülü × (1 − havuz_ücreti)
elektrik TL = ek_güç_W / 1000 × 24 × TL_kWh
net TL = günlük XMR × XMR_TL − elektrik TL
```

## Bu bilgisayar için hesap (SupportXMR %0,6, 3 TL/kWh)

**Ölçülen hız:** XMRig 6.26.0, 24 iş parçacığı, yönetici izni yok (huge pages %0, MSR kapalı) → **~9,8 kH/s**.

| Durum | Hız | Günlük XMR | Brüt TL/gün | Elektrik TL/gün | **Net TL/gün** | **Net TL/ay** |
|---|---|---|---|---|---|---|
| Şu an (ölçüldü) | 9,8 kH/s | 0,00062 | ~20 | ~8,6 (120 W) | **~11** | **~330** |
| Huge pages + MSR (beklenen) | ~18 kH/s | 0,00113 | ~36 | ~10,8 (150 W) | **~25** | **~760** |

- Huge pages + MSR için JinjaMine’ı **yönetici olarak** çalıştırıp Windows oturumunu bir kez kapatıp açmak gerekir
  (03_KURULUM §3.3). Kazancı en çok artıran tek adım budur.
- Uygulamanın *Kazanç* sayfası, madenci çalışırken **ölçülen** hızla ve canlı fiyatla bu tabloyu kendisi hesaplar.
- **Başa baş elektrik fiyatı** (net = 0): 9,8 kH/s’de ~5,5 TL/kWh, 18 kH/s’de ~8 TL/kWh. Elektrik bundan pahalıysa zarar edersin.

## Değişkenler — neden “tahmin”?

1. **XMR fiyatı:** Kazanç XMR olarak gelir. TL karşılığı, sattığın günün fiyatına bağlıdır; fiyat yarıya inerse kazanç da yarıya iner.
2. **Ağ zorluğu:** Daha çok madenci katıldıkça senin payın küçülür.
3. **Havuz şansı (PPLNS):** Havuz blok buldukça ödersin; günlük kazanç dalgalanır, uzun vadede ortalamaya oturur.
4. **Isı ve yıpranma:** Hesaba katılmaz. Sürekli %100 yük işlemciyi “bozmaz” ama fan/termal macun gibi parçaları daha çabuk yorar.

## Ne zaman eline geçer?

- SupportXMR’de ödeme eşiğini **0,003 XMR**’ye indirirsen (~96 TL) şu anki hızla **~5 günde bir**, huge pages ile **~2,7 günde bir** ödeme alırsın.
- Varsayılan eşik 0,1 XMR’dir (~3.200 TL) → ~90–160 gün. Eşik, havuz panelinden cüzdan adresinle değiştirilir.
- Tek başına (solo) kazmak: bu hızla bir blok bulmak ortalama **~1,5–3 yıl** sürer — bu yüzden havuz kullanılır.

## Yapılmaması gerekenler

- Kazancı artırmak için **başkalarının bilgisayarında** (okul, iş yeri, arkadaş) izinsiz kazmak suçtur (bilişim sistemine
  izinsiz müdahale). JinjaMine yalnızca kendi bilgisayarın içindir.
- “2 kat hızlı XMRig”, “madencilik botu”, “bulut madencilik yatırımı” tekliflerinin neredeyse hepsi dolandırıcılıktır.
