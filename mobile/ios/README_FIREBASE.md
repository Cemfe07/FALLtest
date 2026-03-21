# iOS / App Store — Firebase (push)

## Neden gerekli?

Projede `lib/firebase_options.dart` iOS satırları **yanlış / eksik** ise `Firebase.initializeApp(options: …)` **açılışta çökme** veya push hatası üretebilir.  
`GoogleService-Info.plist` ile `firebase_options.dart` iOS değerlerinin **aynı projeyi** göstermesi gerekir.

## Adımlar

1. [Firebase Console](https://console.firebase.google.com) → projene iOS uygulaması ekle (Bundle ID = Xcode’daki `PRODUCT_BUNDLE_IDENTIFIER`).
2. `GoogleService-Info.plist` indir → `ios/Runner/` içine kopyala → Xcode’da Runner hedefine ekle (**Copy items if needed**).
3. Proje kökünde:
   ```bash
   dart pub global activate flutterfire_cli
   dart run flutterfire_cli:configure
   ```
   Oluşan `lib/firebase_options.dart` dosyası hem Android hem iOS satırlarını içermeli.
4. `main.dart` içinde (web hariç) `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` çalışır; iOS’ta da gerçek `firebase_options` kullanılmalıdır.
5. Xcode’da **Push Notifications** capability (ve gerekirse Background Modes → Remote notifications).
6. Gerçek cihaz veya simülatörde **Release** profiliyle açılışı test edin.

## Test

```bash
cd mobile
flutter build ios --release
```

Ardından Xcode → Archive → App Store Connect.

---

## Codemagic (Xcode açmadan)

Önemli: Build başlamadan önce dosya şu yolda olmalı: **`mobile/ios/Runner/GoogleService-Info.plist`** (repo köküne göre).

### Seçenek A — Repoya ekle (en basit, özel repo ise yaygın)

1. [Firebase Console](https://console.firebase.google.com) → proje → iOS uygulaması (`com.anlgzl.lunaura`) → **GoogleService-Info.plist** indir.
2. Dosyayı bilgisayarında şuraya kopyala: **`mobile/ios/Runner/GoogleService-Info.plist`** (Flutter proje kökünden).
3. Git: `git add mobile/ios/Runner/GoogleService-Info.plist` → commit → push.
4. `Runner.xcodeproj` içinde bu plist zaten **Copy Bundle Resources**’ta; ekstra Xcode adımı gerekmez.

### Seçenek B — Repoda tutmak istemiyorsan (Codemagic secret)

1. Aynı plist’i Firebase’den indir.
2. İçeriği **Base64** yap (tek satır, boşluksuz):
   - **PowerShell (Windows):**  
     `[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\tam\yol\GoogleService-Info.plist"))`  
     Çıktıyı kopyala.
   - **macOS / Linux:**  
     `base64 -i GoogleService-Info.plist | tr -d '\n'`
3. Codemagic → uygulaman (**FALL**) → **Environment variables** → **Add variable**
   - **Name:** `GOOGLE_SERVICE_INFO_PLIST_BASE64`
   - **Value:** kopyaladığın base64 metin
   - **Secret** işaretle
   - **Group:** `appstore` (workflow’da `groups: - appstore` kullanılıyorsa bu gruba ekle)
4. Push ettiğin `codemagic.yaml` içinde **Ensure GoogleService-Info.plist** adımı: repoda dosya yoksa bu değişkenden dosyayı yazar.

### Notlar

- Plist’teki **`GOOGLE_APP_ID`**, **`API_KEY`** vb. ile `lib/firebase_options.dart` iOS satırları aynı Firebase uygulamasına ait olmalı.
- Codemagic’te **sertifika / profil / App Store Connect** ayrı; plist sadece Firebase iOS yapılandırması içindir.
