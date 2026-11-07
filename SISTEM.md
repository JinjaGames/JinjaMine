# Sistem özellikleri (2026-11-04 itibarıyla okundu)

| Parça | Değer | Madencilik için anlamı |
|---|---|---|
| İşlemci | **AMD Ryzen 9 7950X** — 16 çekirdek / 32 iş parçacığı, 4,5 GHz taban, **64 MB L3**, 16 MB L2 | RandomX iş parçacığı başına ~2 MB L3 ister. **Ölçülen** (XMRig 6.26.0, yönetici yok, huge pages %0): 16 iş p. ~7,8 kH/s · **24 iş p. ~9,8 kH/s** · 32 iş p. ~8,6–9,7 kH/s. Huge pages + MSR ile ~16–20 kH/s bekleniyor. |
| Bellek | **48 GB** DDR5 (2 × 24 GB), **6000 MT/s** (EXPO açık) | RandomX veri kümesi ~2,3 GB; bol yer var. Hızlı bellek ve düşük gecikme RandomX’e doğrudan yarar. |
| Ekran kartı | **NVIDIA GeForce RTX 5070 Ti** 16 GB, güç sınırı 300 W, sürücü 610.88 | RandomX’te işlemciden çok daha yavaş; GPU coinlerinde bugün kârlılık ~0. Uygulama GPU kullanmaz. |
| Tümleşik grafik | AMD Radeon (iGPU) | Kullanılmaz. |
| Anakart | ASUS PRIME B840M-A WIFI | B840 yonga seti; işlemci güç sınırları BIOS’ta (PBO/Eco Mode). |
| İşletim sistemi | Windows 11 Home | Huge pages için “Bellekte sayfaları kilitle” izni yönetici çalıştırmayla verilir (Home sürümünde de çalışır). |

## Güç ve ısı

- 7950X tüm çekirdekler RandomX’te tipik olarak **~120–170 W** fazladan çeker (BIOS ayarına göre).
  Kazanç hesabında varsayılan **150 W** kullanıldı; prizdeki ölçerle ölçersen *Kazanç* sayfasına gir.
- 7950X 95 °C’ye kadar ısınmak üzere tasarlanmıştır; yine de sürekli kazacaksan:
  - BIOS’ta **Eco Mode (105 W ya da 65 W)** açmak, hızı birkaç yüzde düşürürken gücü ve ısıyı belirgin azaltır —
    kârlılık açısından genelde **daha iyi**dir (H/s başına watt düşer).
  - Kasa hava akışını kontrol et; sıcaklığı HWiNFO gibi bir programla izle.

## Ölçüm notları (2026-11-04)

- XMRig 6.26.0 resmî sürüm (SHA-256 doğrulandı). Windows Defender ilk çalıştırmada “Trojan:Win64/HashvaultMiner.A”
  diye engelledi; kullanıcı “Cihazda izin ver” ile geri yükledi.
- İş parçacıklarını önce her fiziksel çekirdeğe birer tane sabitlemek (JinjaMine bunu otomatik yapar) 12 iş parçacığında
  sabitlenmemişe göre ~%40 daha hızlıydı (7,6 vs 5,4 kH/s).
- Ölçümler huge pages ve MSR kapalıyken yapıldı; yönetici izniyle tekrar ölçülmeli.

## Önerilen başlangıç ayarı (JinjaMine → Madenci ayarları)

- Bilgisayarı kullanırken: **Dengeli** (kullanırken 8, boştayken 24 iş parçacığı, öncelik düşük).
- Gece/sadece madencilik: **Tam güç** (24 iş parçacığı — bu bilgisayarda ölçülen en iyisi). Huge pages açıldıktan sonra 24/28/32’yi Panel’deki 15 dk hızıyla karşılaştır.
- Huge pages + MSR için JinjaMine’ı bir kez **yönetici olarak** çalıştır, ardından Windows’ta oturumu kapatıp aç.
