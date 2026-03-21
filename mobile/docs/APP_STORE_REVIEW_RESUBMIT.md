# App Store Review — “Crash on launch” (2.1) yeniden gönderim

## Ne oldu?

Apple, **build 38** (ve benzeri eski sürümler) için **açılışta çökme** bildirdi (ör. iPad Air, iPadOS 26.x). Bu genelde **iOS Firebase yapılandırması eksik/yanlış** (`GoogleService-Info.plist`, `firebase_options`), **FCM init sırası** veya **release’te debug-only katmanlar** ile ilişkilidir.

## Repoda yapılan düzeltmeler (özet)

- `GoogleService-Info.plist` + `lib/firebase_options.dart` iOS satırları **eşleştirildi**
- `FirebaseMessaging.onBackgroundMessage` **`runApp` öncesi** kayıtlı; Firebase **`FirebaseBootstrap.ensureInitialized()`** ile tek giriş noktası (iOS **çift `FIRApp` kaydı / SIGABRT** önlenir)
- Release’ta **DevicePreview kapalı** (`kReleaseMode`)
- Push için **entitlements** (`aps-environment`) + Apple’da **Push** açık **App Store provisioning profile**
- `main.dart`: `FlutterError.onError` + `PlatformDispatcher.instance.onError` ile yakalanmayan hataların loglanması

## Senin yapman gerekenler

1. **Yeni binary üret** — App Store Connect’e **build 45+** (veya mevcut `pubspec` içindeki `+` numarası) yükle. **Eski 38’i tekrar gönderme.**
2. **TestFlight’ta iPad’de dene** (mümkünse Apple’ın belirttiği benzer cihaz/OS): uygulama **soğuk açılış** ile açılmalı.
3. **App Store Connect → Resolution Center** içinde Apple’a kısa yanıt yaz (aşağıdaki İngilizce metni kopyalayabilirsin).

## Apple’a örnek İngilizce yanıt (kopyala-yapıştır)

```
Hello App Review Team,

Thank you for the feedback. We have addressed the launch crash reported on iPad.

Changes in the new build:
- Corrected Firebase iOS configuration (GoogleService-Info.plist and Dart Firebase options aligned).
- Centralized Firebase initialization to prevent duplicate default-app configuration on iOS (FIRApp crash). FCM background handler uses the same guard; registration still occurs before app start.
- Ensured release builds do not use debug-only UI wrappers.
- Updated iOS signing entitlements for push notifications to match the provisioning profile.

We tested cold launch on iPad and iPhone with this new build. Please review the newly uploaded binary (build XX).

Best regards
```

*(İçindeki `build XX` yerine gerçek build numaranı yaz.)*

## Crash log (.ips) sembolize etme

1. `.ips` dosyasını **Xcode → Window → Devices and Simulators → View Device Logs** veya **atos** ile sembolize et.
2. İlk birkaç satırda genelde **Flutter**, **Firebase**, **FIRApp configure** vb. görünür — ona göre kod tarafını doğrula.

## Not

Kullanıcı verisi **sunucuda** (`X-Device-Id`); uygulamayı silmek geçmiş okumaları silmez. Bu, çökme ile ilgili değildir; profil ekranından **kalıcı sil** ile yönetilir.
