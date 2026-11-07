# 7. Kârlılık sıralaması, sıcaklık, bakiyeler

## Kârlılık: “Ne kazmalı, nerede?”

*Kârlılık* sayfası her seçeneği bu bilgisayarın hızıyla karşılaştırır. Madenci çalışıyorsa ölçülen 15 dakikalık hız,
çalışmıyorsa *Kazanç hesabı*ndaki varsayılan hız kullanılır.

| Veri | Kaynak | Yenilenme |
|---|---|---|
| Coinlerin XMR’ye göre göreli getirisi (anlık ve 24 sa ortalama), 24 sa işlem hacmi | WhatToMine CPU listesi | 30 dk’da bir + “Yenile” |
| Monero zorluğu, blok ödülü | xmrchain.net | 10 dk’da bir |
| XMR, BTC, TRX, LTC, DOGE, USDT fiyatları (TL) | CoinGecko | 30 dk’da bir |
| unMineable ödeme eşiği | unMineable API | her yenilemede |
| Havuz gecikmesi | Bu bilgisayardan TCP bağlantı süresi | her yenilemede |

Sütunlar:

- **Günlük brüt:** havuz ücreti düşülmüş beklenen kazanç (TL).
- **Net:** brütten elektrik düşülür (ek güç × 24 sa × TL/kWh).
- **Ödeme süresi:** havuzun en düşük ödeme eşiğine ulaşma süresi.
- **Likidite:** coinin borsalardaki 24 saatlik hacmi. 0,5 BTC altı **sığ piyasa** sayılır; kazılan coin fiyatı
  düşürmeden satılamaz.

Sıralama ölçütleri:

- En kârlı (şu an)
- En kârlı (24 sa ortalama)
- En düşük ücret
- En hızlı ödeme
- En düşük gecikme
- Likidite

**Önerilen seçenek** şu kurallarla seçilir:

- JinjaMine’ın gerçekten çalıştırabildiği seçenekler arasından seçilir.
- Likit olmalı ve tahmini güvenilir olmalıdır.
- En yüksek net kazanç kazanır.
- %0,1’den küçük farklarda gecikmesi düşük olan seçilir.

Sığ piyasalı coinler (ör. Etica, EPIC) kâğıt üzerinde daha yüksek görünse de önerilmez.

2026-11-04 itibarıyla ~9,8 kH/s ile sıralama şöyleydi:

| Seçenek | Brüt | Net (günlük) |
|---|---|---|
| MoneroOcean, XMR (%0 ücret, önerilen) | ~18,8 TL | ~8,0 TL |
| SupportXMR | ~18,7 TL | ~7,9 TL |
| unMineable → TRX | ~18,6 TL | ~7,8 TL |

Diğer RandomX coinlerinin (ZEPH, QRL, XTM) hepsi XMR’nin yarısı kadar ya da daha az kazandırıyordu.

### Otomatik geçiş

*Kârlılık* sayfasındaki **Otomatik geçiş** açıksa JinjaMine şu koşullarda başka bir seçeneğe geçer:

- Seçenek, **adresi girilmiş** seçeneklerden biri olmalı.
- Hem anlık hem 24 saatlik ortalamada şu ankinden **en az %5 daha kârlı** olmalı.
- Bu durum **art arda iki yenilemede** sürmeli.

Bu koşullar küçük dalgalanmalarda gidip gelmeyi önler. Her geçiş havuz bakiyesini böler: eski havuzdaki bakiye kendi
eşiğine ulaşana kadar orada bekler. *Bakiyeler* sayfası hepsini gösterir.

## Kâr koruması

*Madenci ayarları → Kâr koruması* açıksa, net sonuç eksiye düştüğünde madenci duraklar. Bu, elektriğin kazançtan
pahalı olduğu durumdur (ör. XMR fiyatı düştüğünde ya da elektrik zamlandığında). Net sonuç artıya dönünce madenci devam eder.

## Otomatik hız ayarı

*Madenci ayarları → Otomatik hız ayarı* madenci çalışırken bir dizi iş parçacığı sayısını canlı dener. 32 çekirdekte
denenen sayılar 16, 20, 24, 28 ve 32’dir.

- Yeniden başlatma yapılmaz.
- Her sayıda 25 sn yerleşme beklenir, ardından 30 sn ölçülür.
- En hızlı sayı kaydedilir. Fark %1’den azsa daha az iş parçacığı seçilir: daha serin ve daha az elektrik.
- Sıcaklık sınırındayken yapılan ölçümler sayılmaz.

Huge pages’i açtıktan ya da yönetici olarak çalıştırdıktan sonra yeniden çalıştır; en iyi sayı değişir.

## Sıcaklık

| Parça | Nasıl okunur |
|---|---|
| Ekran kartı (RTX 5070 Ti) | `nvidia-smi` (sürücüyle gelir, yönetici gerekmez): sıcaklık, yük, güç, fan. |
| İşlemci (Ryzen 7950X) | Windows bu sıcaklığı sürücüsüz vermez. Seçenekler aşağıda. |

İşlemci sıcaklığı için seçenekler:

- **LibreHardwareMonitor** (ücretsiz, açık kaynak) yönetici olarak açık tutulursa JinjaMine sıcaklığı WMI üzerinden okur.
- LibreHardwareMonitor’da *Options → Remote Web Server → Run* açılırsa JinjaMine sıcaklığı `localhost:8085` üzerinden okur.
- İkisi de yoksa ve JinjaMine yönetici olarak çalışıyorsa ACPI bölgesi denenir. Bu yalnızca yaklaşık bir değerdir.

Geri bildirim her yerde aynı renk dilini kullanır:

| Renk | Durum |
|---|---|
| Mavi, ❄ | Serin (CPU < 50 °C, GPU < 45 °C) |
| Yeşil | Normal |
| Sarı, ⚠ | Sınıra 10 °C’den az kaldı. Bildirim gelir, günlüğe yazılır. |
| Kırmızı, 🔥, nabız gibi parlayan | Sınırın üstünde. Bildirim 10 sn kalır, günlüğe hata olarak yazılır; işlemcide koruma devreye girer. |

Sıcaklık şu yerlerde görünür:

- Panel’deki iki gösterge: sınır çizgisi, renkli ölçek ve öneri.
- Sol menünün altındaki CPU ve GPU çipleri.
- Madenci ayarlarındaki iş parçacığı bölümünün yanı.

**Sıcaklık koruması** (varsayılan açık, sınır 90 °C) şöyle çalışır:

- İşlemci sınırı 20 sn aşarsa iş parçacığı %25 azaltılır; sıcaklık yüksek kalırsa azaltma tekrarlanır.
- Sınırın 8 °C altında 2 dk kalınca iş parçacığı kademeli olarak geri artırılır.
- Ekran kartı için yalnızca uyarı verilir; JinjaMine ekran kartıyla kazmaz. Varsayılan GPU sınırı 83 °C.

## Bakiyeler

*Bakiyeler* sayfası kazmak için kullandığın **her havuz/adres** çiftini hatırlar. Havuz değiştirsen de eskisi
listede kalır.

| Kart | Anlamı |
|---|---|
| Kazılan (bu uygulamayla) | XMRig’in yaptığı işin ağ ödülüyle değeri. Havuz ücreti ve XMRig bağışı düşülür. Tahmindir; kalıcı olarak saklanır. |
| Bu oturumda | Aynı hesap, bu açılıştan beri. |
| Havuzlarda bekleyen | Havuzda biriken, henüz ödenmemiş miktar (XMR havuzlarının toplamı). |
| Cüzdana aktarılan | Havuzun cüzdana gönderdiği toplam. Altta tarih, tutar ve blok gezgini bağlantısıyla ödeme listesi. |

Bakiye ve ödeme listesi uygulama içinden şu havuzlarda okunur:

- SupportXMR ve MoneroOcean: bekleyen, ödenen, havuzun ölçtüğü hız, son pay, ödeme listesi.
- unMineable: bekleyen, ödenen, hız, ödemeler.

HashVault ve NiceHash için web paneli bağlantısı verilir.
