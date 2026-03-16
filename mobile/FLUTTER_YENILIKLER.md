# Flutter ile Yapılan Yenilikler (Özet)

Bu dosya, projede Flutter ile eklenen veya güncellenen özellikleri listeler.

---

## 1. Ana ekran (Home)

- **Kademeli kart giriş animasyonu**  
  Servis kartları (Kahve, El, Tarot, vb.) sırayla, aşağıdan yukarı kayarak ve fade-in ile görünüyor.

- **“AI destekli kişisel rehberin” pill animasyonu**  
  Hafif nabız (scale + glow) ile sürekli canlı görünüm.

- **Zamana göre karşılama**  
  Günaydın / İyi günler / İyi akşamlar metni saate göre değişiyor.

- **Bugünün sözü / Günün kartı**  
  Her gün değişen kısa söz + “Günün kartı” etiketi (tarih bazlı, aynı gün aynı içerik).

- **Parallax**  
  Listeyi aşağı kaydırınca üst blok (başlık, pill, karşılama, bugünün sözü) hafifçe yukarı gidiyor.

- **Popüler rozeti**  
  Son 7 günde en çok açılan analiz kartında “Popüler” rozeti (altın, trending_up ikonu) gösteriliyor; açılışlar cihazda kaydediliyor.

- **Kart basma animasyonu**  
  Servis kartlarına basınca hafif küçülme (scale 0.98) ile dokunma geri bildirimi.

- **Bugünkü burcun**  
  Profil’de doğum tarihi varsa burç otomatik hesaplanır; günlük kısa burç yorumu gösterilir. Tarih yoksa “Burcunu keşfet” ile Profil’e gidilir.

- **Ay evresi**  
  Bugünkü ay evresi (Yeni Ay, Hilal, İlk Dördün, Dolunay vb.) ve kısa anlamı tek satırda.

- **Günün enerjisi**  
  Dört etkileşimli chip: Enerjik, Sakin, Meraklı, Romantik. Tıklanınca o enerjiye göre kısa motivasyon mesajı (SnackBar) gösterilir.

**Dosyalar:** `lib/features/home/home_screen.dart`, `lib/services/daily_quote_service.dart`, `lib/services/feature_usage_service.dart`, `lib/services/daily_horoscope_service.dart`, `lib/services/daily_energy_service.dart`, `lib/utils/zodiac_utils.dart`, `lib/utils/moon_phase_utils.dart`

---

## 2. Ödeme ekranları (tüm fal türleri)

- **Tek tip tasarım**  
  Kahve, El, Tarot, Nümeroloji, Doğum Haritası, Kişilik, Sinastri hepsi:
  - Aynı arka plan: `scrimOpacity: 0.84`, `patternOpacity: 0.16`
  - AppBar: “Ödeme”
  - GlassCard + GradientButton
  - Buton: “Ödemeyi Başlat ve Yorumu Gör”
  - Alt metin: “Ödeme sonrası yorum hazırlanır ve sonuç ekranına otomatik yönlendirilirsin.”

**Dosyalar:**  
`lib/features/coffee/coffee_payment_screen.dart`, `hand_payment_screen.dart`, `tarot_payment_screen.dart`, `numerology_payment_screen.dart`, `birthchart_payment_screen.dart`, `personality_payment_screen.dart`, `synastry_payment_screen.dart`

---

## 3. Yorum bekleniyor / işleniyor ekranları

- **Tek tip tasarım**  
  Tüm türlerde (Tarot, Kahve, El, Nümeroloji, Doğum Haritası, Kişilik, Sinastri):
  - AppBar: “Yorumunuz hazırlanıyor”
  - Aynı scaffold (scrimOpacity 0.84, patternOpacity 0.16)
  - 56×56 CircularProgressIndicator (renk: 0xFF6DD5FA)
  - Ortak metin: “Adım 1: Ödeme alındı ✓ / Adım 2: AI yorumu oluşturuluyor… / Lütfen bu ekranda kalın.”

**Dosyalar:**  
`lib/features/tarot/tarot_processing_screen.dart`, `coffee_loading_screen.dart`, `hand_loading_screen.dart`, `numerology_loading_screen.dart`, `birthchart_loading_screen.dart`, `personality_generating_screen.dart`, `synastry_generating_screen.dart`

---

## 4. Profil – Benim Okumalarım

- **Son 5 yorum**  
  Sadece en güncel 5 okuma listeleniyor (backend limit 5, uygulama tarafında da `take(5)`).

**Dosyalar:** `lib/features/profile/profile_screen.dart`, `lib/services/profile_api.dart`

---

## 5. Doğum haritası boş yorum

- **Sonuç ekranı**  
  Yorum boş geldiğinde “Yorum boş döndü.” yerine açıklayıcı mesaj: “Yorum henüz hazır değil veya bir hata oluştu. Lütfen Benim Okumalarım'dan tekrar kontrol edin…”

**Dosya:** `lib/features/birthchart/birthchart_result_screen.dart`

---

## 6. Arka plan ve iskelet

- **MysticScaffold**  
  Siyah ekran riskine karşı `Scaffold` arka plan rengi: `Color(0xFF0D0D1A)` (numeroloji vb. bekleme ekranlarında).

- **MysticBackground – yıldız drift**  
  Arka plandaki yıldızlar yavaşça hareket ediyor (sin/cos ile drift, ekran içinde kalacak şekilde).

**Dosyalar:** `lib/widgets/mystic_scaffold.dart`, `lib/widgets/mystic_background.dart`

---

## 7. Kart bileşeni (FeatureCard)

- **Popüler rozeti**  
  `showPopularBadge: true` ise başlık satırında “Popüler” rozeti (altın, trending_up ikonu).

- **Basma animasyonu**  
  Dokunulduğunda 0.98 scale ile hafif küçülme (80 ms).

**Dosya:** `lib/widgets/feature_card.dart`

---

## 8. Servisler (Flutter tarafı)

- **DailyQuoteService**  
  Tarihe göre günlük söz ve “Günün kartı” etiketi (offline, deterministik).

- **FeatureUsageService**  
  Analiz açılışlarını kaydeder; son 7 günde en çok açılanı hesaplar (`SharedPreferences`).

**Dosyalar:** `lib/services/daily_quote_service.dart`, `lib/services/feature_usage_service.dart`

---

## Kısa liste (tek bakışta)

| Konu | Yenilik |
|------|--------|
| Ana ekran | Giriş animasyonu, pill nabız, karşılama, bugünün sözü, parallax, Popüler rozeti, kart scale |
| Ödeme | Tüm türlerde aynı tasarım (scrim, GlassCard, GradientButton, alt metin) |
| Yorum bekleniyor | Tüm türlerde aynı başlık, progress, adım metni |
| Profil | Son 5 yorum |
| Doğum haritası | Boş yorum için açıklayıcı mesaj |
| Arka plan | Koyu fallback rengi, yıldız drift |
| FeatureCard | Popüler rozeti, basma animasyonu |
| Servisler | Günlük söz, haftalık kullanım istatistiği |

Bu özelliklerin backend tarafı (FCM, doğum haritası retry, device_id, limit 5 vb.) ilgili API ve sunucu dosyalarında yapıldı; bu liste yalnızca **Flutter (mobil) tarafındaki** yenilikleri içerir.
