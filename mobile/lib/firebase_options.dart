// Android: `android/app/google-services.json` ile aynı olmalı.
// iOS: Firebase Console'daki iOS uygulaması (bundle com.anlgzl.lunaura).
// API_KEY iOS'ta farklıysa `GoogleService-Info.plist` içindeki `API_KEY` ile değiştir.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  /// `google-services.json` — `com.anlgzl.lunaura`
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBJ0BXJncSkqxybuwqXZXNwqySTV0EsO0A',
    appId: '1:230939701808:android:dd5d84a5a2618d7ac1f3f5',
    messagingSenderId: '230939701808',
    projectId: 'fall-c708b',
    storageBucket: 'fall-c708b.firebasestorage.app',
  );

  /// iOS — `GoogleService-Info.plist` ile birebir (GOOGLE_APP_ID, API_KEY).
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA8O_gG4rghlk19prKwSaqUM6Iog5U9gnY',
    appId: '1:230939701808:ios:eff09d7abcbc4e3dc1f3f5',
    messagingSenderId: '230939701808',
    projectId: 'fall-c708b',
    storageBucket: 'fall-c708b.firebasestorage.app',
    iosBundleId: 'com.anlgzl.lunaura',
  );

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return android;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return ios;
      default:
        return android;
    }
  }
}
