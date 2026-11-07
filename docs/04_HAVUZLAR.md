# 4. Havuzlar

## Havuz nedir?

Monero’da her 2 dakikada bir blok bulunur ve ödülü (~0,6 XMR) bulan alır. Senin hızınla tek başına blok bulmak
ortalama ~1,5 yıl sürer. **Havuz**, binlerce madencinin işini birleştirir; havuz blok buldukça herkese katkısı
oranında öder. Katkı “pay” (share) ile ölçülür: XMRig havuzun verdiği kolay hedefleri çözdükçe “accepted” satırları görürsün.

## JinjaMine’daki hazır havuzlar

| Havuz | Adres (TLS) | Ücret | En düşük ödeme | Not |
|---|---|---|---|---|
| **SupportXMR** | pool.supportxmr.com:443 | %0,6 | 0,003 XMR (ayarlanırsa) | Eski, büyük, güvenilir. JinjaMine bakiyeyi okur. **Önerilen.** |
| **MoneroOcean** | gulf.moneroocean.stream:20128 | %0 | 0,003 XMR | Ödeme XMR. Kendi XMRig sürümüyle algoritma değiştirir; standart XMRig ile RandomX kazılır. JinjaMine bakiyeyi okur. |
| **HashVault** | pool.hashvault.pro:443 | %0,9 | 0,01 XMR | Bakiye web panelinden izlenir. |
| **P2Pool** | 127.0.0.1:3333 (yerel) | %0 | yok (doğrudan bloktan) | Merkezi değil. Bilgisayarda `monerod` (tam düğüm, ~250 GB, ilk eşitleme 1–3 gün) + `p2pool` gerekir. İleri düzey. |
| Özel | sunucu:port | — | — | İstediğin havuzu elle gir. |

Hepsi şifreli (TLS) bağlantıyla çalışır; sertifikalar havuzların kendi imzalıdır, XMRig bunu kabul eder.

## PPLNS ne demek?

“Son N payı öde”: havuz blok bulduğunda, son dönemde pay gönderenler arasında paylaştırılır. Kısa vadede dalgalanır
(bir gün az, ertesi gün çok), uzun vadede beklenen değere oturur. Sık sık havuz değiştirmek bu yüzden zarar ettirir:
**birini seç ve kal.**

## Ödeme eşiği

- Havuzda biriken bakiye eşiği geçince cüzdanına gönderilir; her gönderide küçük bir ağ ücreti kesilir.
- SupportXMR: siteye gir → *Dashboard* → adresini yaz → *Payment threshold* → 0,003 XMR (düşük eşikte havuz küçük bir ücret alır).
- JinjaMine’daki *Kazanç* sayfası “ödeme eşiğine ~N gün” diye gösterir.

## Birden çok bilgisayar

Aynı cüzdanı birden çok bilgisayarda kullanabilirsin. Her birine *Cüzdan ve ödeme → Bu bilgisayarın adı* kısmında
farklı ad ver (ör. `masaustu`, `laptop`); havuz panelinde ayrı ayrı görünürler.
