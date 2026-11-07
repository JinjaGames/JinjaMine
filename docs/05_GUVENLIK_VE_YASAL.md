# 5. Güvenlik ve yasal durum

## Güvenlik kuralları

1. **25 kelime (seed) yalnızca kâğıtta.** Hiçbir programa, siteye, “destek” görevlisine verme. JinjaMine dahil hiçbir
   madencilik programının buna ihtiyacı yoktur.
   - İstisna, JinjaMine’ın kendi oluşturduğu **yerel cüzdan**dır (“Henüz cüzdanım yok”).
   - Onun anahtarları yalnızca bu bilgisayarda, Windows DPAPI ile şifreli durur.
   - Yedek dosyası (`YEREL_CUZDAN_YEDEK.txt`) paraya erişim demektir: USB’ye ya da kâğıda al, masaüstündeki kopyayı sil.
2. **XMRig yalnızca resmî GitHub’dan**, SHA256SUMS ile doğrulanarak. “Hızlandırılmış / ücretsiz premium” sürümler
   genellikle cüzdan adresini kendininkiyle değiştirir ya da virüs taşır.
3. **Defender dışlaması yalnızca `mine\xmrig` klasörü.** Diskin tamamını dışlama.
4. JinjaMine’ın XMRig API’si yalnızca `127.0.0.1`’e (bu bilgisayar) açılır ve her başlatışta rastgele bir parola kullanır;
   ağdaki başka cihazlar erişemez.
5. JinjaMine, kapatıldığında XMRig’i de kapatır. Görev Yöneticisi’nde JinjaMine kapalıyken `xmrig.exe` görürsen kapat ve nedenini araştır.
6. JinjaMine hiçbir zaman ekran kartı sürücüsü, BIOS ya da Windows güvenlik ayarı değiştirmez. Yaptığı tek sistem
   değişikliği, senin açtığında “Windows açılınca başlat” kaydıdır (HKCU\…\Run, kapatınca silinir).

## Türkiye’de yasal durum (genel bilgi — hukuki tavsiye değildir)

- **Kendi bilgisayarında, kendi elektriğinle** kripto para kazmak Türkiye’de yasak değildir.
- **Başkasının cihazında/elektriğiyle izinsiz** kazmak (okul, iş yeri, yurt, kiralık sunucuda kurallara aykırı)
  suç teşkil edebilir (bilişim sistemine izinsiz girme/verileri bozma, hırsızlık). Yurtta/ortak elektrikte kazma;
  kiradaysan sözleşmeni kontrol et.
- 2021’den beri kripto varlıklarla **ödeme yapılması** yasaktır; alıp satmak ve tutmak serbesttir. Kripto varlık
  hizmet sağlayıcıları SPK lisansına tabidir — işlem yaptığın borsanın lisanslı olup olmadığını kontrol et.
- **Vergi:** Madencilikten ve kripto alım-satımından elde edilen kazancın vergilendirilmesi konusunda düzenlemeler
  değişmektedir. Düzenli ve büyük tutarlara ulaşırsan bir mali müşavire danış; kazancın tarih/miktar kaydını tut
  (havuz panelinin ödeme listesi ve cüzdan geçmişi bunun için yeterlidir).
- Monero bazı borsalarda (gizlilik özelliği nedeniyle) listeden kaldırılmıştır; satış seçenekleri sınırlı olabilir.

## Donanım

- Uzun süreli %100 yük işlemciye zarar vermez (sıcaklık sınırları içinde), ama fan, güç kaynağı ve termal macun
  daha çabuk yaşlanır. Eco Mode ile çalıştırmak hem verimi artırır hem yıpranmayı azaltır.
- Dizüstü bilgisayarda sürekli kazma önerilmez (ısı + batarya). JinjaMine, XMRig’e “pilde duraklat” ayarını verir.
