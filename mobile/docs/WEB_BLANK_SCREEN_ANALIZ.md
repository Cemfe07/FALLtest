# Web Boş Ekran / Terminal Assertion – Önce/Sonra Analizi

## Zaman çizelgesi

### 1. “Günün manifesti” promptundan **ÖNCE**
- Ana sayfa: Tek `ListView` (veya scroll) içinde header + kartlar.
- Header: Bilgelik kartı (tek kutu), sonra Row (Burç + Ay), sonra Günün enerjisi chip’leri.
- Widget ağacı nispeten sade; az sayıda hit-test hedefi.

### 2. “Günün manifesti” eklendi
- **Yapılan:** `DailyManifestService` + ana sayfada tek bir **tam genişlik Container** (manifest kartı), Bilgelik kartı ile Burç/Ay satırı arasına eklendi.
- **Yapısal etki:** Header’a tek blok eklendi; scroll/layout yapısı değişmedi. Tek başına bu ekleme boş ekranı açıklamaz.

### 3. “Konumlandırma estetik” (estetik düzen)
- **Yapılan:** Tüm üst blok yeniden düzenlendi:
  - Bölüm başlıkları (“Bugün senin için”, “Günün enerjisi”),
  - Bilgelik + Manifest **yan yana** (Row içinde iki Expanded),
  - Daha fazla Container, BoxDecoration, boxShadow, padding.
- **Yapısal etki:** Header’da çok daha fazla widget, iç içe Row/Column/Expanded ve gölgeli kutular. Hit-test ve layout karmaşıklığı arttı.

### 4. Sonuç
- Web’de (Chrome) ana içerik alanı bazen **boş** görünüyor, sadece alt bar kalıyordu.
- Terminalde **mouse_tracker.dart** “Assertion failed” mesajları tekrarlanıyordu.

---

## Kök neden

1. **Asıl tetikleyici: DevicePreview + Web**  
   Debug modda uygulama `DevicePreview` ile sarılı (telefon çerçevesi). Web’de bu:
   - Ek koordinat dönüşümü ve overlay katmanları ekliyor,
   - Pointer (mouse/touch) olaylarının sırası/konumu karışıyor,
   - Flutter web’deki bilinen **mouse_tracker** hatası tetikleniyor → assertion → bazen çizim atlanıyor (boş alan).

2. **Neden “manifest”ten sonra fark edildi?**  
   - Sadece manifest kartını eklemek yapıyı çok az değiştirdi; tek başına sebep değil.
   - Ardından gelen **estetik düzen** ile header çok büyüdü: daha fazla widget, daha fazla hit-test bölgesi. Bu da web’de pointer olaylarının karışma ihtimalini artırdı.
   - Yani: Sorun **DevicePreview (web)** ile zaten vardı; **manifest + estetik** ile ağaç ağırlaşınca belirgin hale geldi.

3. **Özet**  
   - Hata: **Flutter web + DevicePreview** ile pointer/mouse_tracker uyumsuzluğu.  
   - Görünür olması: **Günün manifesti** ve özellikle **estetik düzen** ile widget sayısı ve karmaşıklığı artınca bu hata daha sık ortaya çıktı.

---

## Yapılan düzeltmeler

1. **`main.dart`**  
   Web’de DevicePreview kapatıldı:  
   `enabled: !kReleaseMode && !kIsWeb`  
   Böylece web’de çerçeve/overlay yok; pointer olayları doğrudan uygulama alanına gidiyor.

2. **`home_screen.dart`**  
   - Scroll içeriği `_buildScrollContent()` ile ayrıldı.
   - Web’de `FadeTransition` kullanılmıyor (sadece scroll içeriği); diğer platformlarda FadeTransition aynen kullanılıyor.
   - Bu sayede web’de daha az animasyon/katman, daha az pointer karışması riski.

---

## İleride dikkat edilecekler

- Web’de **DevicePreview’ı tekrar açmayın** (debug bile olsa); aksi halde boş ekran / mouse_tracker assertion geri gelebilir.
- Ana sayfa header’ına çok fazla iç içe interaktif widget (GestureDetector, InkWell vb.) eklerken web’de test edin; gerekirse web’e özel sade bir layout düşünülebilir.
