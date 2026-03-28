import 'package:flutter/foundation.dart'
    show kDebugMode, kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:device_preview/device_preview.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';

import 'core/app_theme.dart';
import 'features/home/home_screen.dart';
import 'features/landing/landing_screen.dart';
import 'features/legal/legal_consent_gate_screen.dart';
import 'features/profile/profile_screen.dart';

// ✅ Synastry
import 'features/synastry/synastry_intro_screen.dart';

// ✅ IAP Debug Screen
import 'features/iap/iap_debug_screen.dart';

// ✅ IAP service
import 'services/iap_service.dart';
// ✅ Push: yorum hazır bildirimi
import 'services/notification_service.dart'
    show NotificationService, firebaseMessagingBackgroundHandler;
import 'services/firebase_bootstrap.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    if (kDebugMode) {
      debugPrint('[platformDispatcher.onError] $error\n$stack');
    }
    return true;
  };

  // FCM: arka plan handler runApp öncesi kayıtlı olmalı (FlutterFire).
  if (!kIsWeb) {
    try {
      await FirebaseBootstrap.ensureInitialized()
          .timeout(const Duration(seconds: 12));
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[main] Firebase init: $e\n$st');
      }
    }
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  // Release'te DevicePreview sarmalayıcısı yok — App Store / iPad incelemesinde ek risk oluşturmasın.
  if (kReleaseMode) {
    runApp(const FallApp());
  } else {
    runApp(
      DevicePreview(
        enabled: true,
        builder: (context) => const FallApp(),
      ),
    );
  }
}

class FallApp extends StatefulWidget {
  const FallApp({super.key});

  @override
  State<FallApp> createState() => _FallAppState();
}

class _FallAppState extends State<FallApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  Future<void> _bootstrapCoreServices() async {
    if (kIsWeb) return;

    // Push/FCM: Firebase [FirebaseBootstrap] ile main()'de zaten başlatıldı.

    try {
      await NotificationService.init().timeout(const Duration(seconds: 12));
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[Bootstrap] Notification init skipped: $e\n$st');
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Servis açılışları runApp'i asla bloklamasın.
    unawaited(_bootstrapCoreServices());
    NotificationService.onOpenReadingsRequested = _openReadingsFromNotification;

    // ✅ IAP "hazır mı?" kontrolü (debug log). Akışı bozmaz.
    _debugCheckIapAvailability();
  }

  Future<void> _debugCheckIapAvailability() async {
    try {
      final available = await InAppPurchase.instance.isAvailable();
      if (kDebugMode) {
        debugPrint('[IAP] isAvailable = $available');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[IAP] isAvailable check failed: $e');
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationService.onOpenReadingsRequested = null;

    // ✅ Purchase stream subscription varsa temizle (async; beklemeden başlat)
    unawaited(IapService.instance.dispose());

    super.dispose();
  }

  void _openReadingsFromNotification() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = _navKey.currentState;
      if (nav == null) return;
      nav.push(
        MaterialPageRoute(
          builder: (_) => const ProfileScreen(
            openWithMessage: "Yorumunuz hazır olabilir. Benim Okumalarım'dan kontrol edin.",
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: _navKey,

      // DevicePreview yalnızca debug/profile
      locale: kReleaseMode ? null : DevicePreview.locale(context),
      builder: kReleaseMode ? null : DevicePreview.appBuilder,

      theme: AppTheme.dark(),

      // İlk ekran: yasal onay yapılmamışsa gate, yapıldıysa ana ekran
      home: const LegalConsentGateScreen(),

      // ✅ TR/EN
      supportedLocales: const [
        Locale('tr', 'TR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // ✅ Named routes
      routes: {
        '/home': (_) => const HomeScreen(),
        '/landing': (_) => const WelcomeLandingScreen(),
        '/legal-gate': (_) => const LegalConsentGateScreen(),
        '/synastry': (_) => const SynastryIntroScreen(),
        '/iap-debug': (_) => const IapDebugScreen(),
      },
    );
  }
}
