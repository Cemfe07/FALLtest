import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, debugPrint;

import '../firebase_options.dart';

/// Firebase varsayılan uygulamasının **yalnızca bir kez** başlatılmasını garanti eder.
///
/// iOS'ta iki kez `configure` çağrısı `FIRApp addAppToAppDictionary` ile SIGABRT üretir
/// (Apple inceleme crash log'ları). Paralel `initializeApp` yarışlarını da önler.
class FirebaseBootstrap {
  FirebaseBootstrap._();

  static Future<void>? _inFlight;

  /// Web'de no-op. Diğer platformlarda boşsa tek Future üzerinden init.
  static Future<void> ensureInitialized() async {
    if (kIsWeb) return;
    if (Firebase.apps.isNotEmpty) return;

    _inFlight ??= _initializeDefaultApp();
    try {
      await _inFlight!;
    } catch (e, st) {
      // Native tarafta app zaten oluşmuş olabilir; Dart listesi gecikmeli güncellenirse yakala.
      if (Firebase.apps.isNotEmpty) {
        return;
      }
      _inFlight = null;
      if (kDebugMode) {
        debugPrint('[FirebaseBootstrap] init failed: $e\n$st');
      }
      rethrow;
    }
  }

  static Future<void> _initializeDefaultApp() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}
