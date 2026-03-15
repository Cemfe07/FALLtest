// FlutterFire CLI ile güncelleyin: dart run flutterfire_cli:configure
// Bu dosya Firebase Console'dan Android uygulaması ekleyip google-services.json indirdikten sonra
// oluşturulur. Şimdilik stub: push bildirimleri çalışmaz ama uygulama derlenir.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return FirebaseOptions(
      apiKey: 'stub',
      appId: '1:000000000000:android:0000000000000000000000',
      messagingSenderId: '000000000000',
      projectId: 'lunaura-stub',
      storageBucket: 'lunaura-stub.appspot.com',
    );
  }
}
