import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:device_preview/device_preview.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/app_theme.dart';
import 'features/home/home_screen.dart';
import 'features/legal/legal_consent_gate_screen.dart';
import 'features/profile/profile_screen.dart';

// ✅ Synastry
import 'features/synastry/synastry_intro_screen.dart';

// ✅ IAP Debug Screen
import 'features/iap/iap_debug_screen.dart';

// ✅ IAP service
import 'services/iap_service.dart';
// ✅ Push: yorum hazır bildirimi
import 'services/notification_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  await NotificationService.init();

  runApp(
    DevicePreview(
      enabled: !kReleaseMode, // debug modda açık
      builder: (context) => const FallApp(),
    ),
  );
}

class FallApp extends StatefulWidget {
  const FallApp({super.key});

  @override
  State<FallApp> createState() => _FallAppState();
}

class _FallAppState extends State<FallApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

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

    // ✅ Purchase stream subscription varsa temizle
    IapService.instance.dispose();

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

      // ✅ DevicePreview için gerekli
      useInheritedMediaQuery: true,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,

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
        '/legal-gate': (_) => const LegalConsentGateScreen(),
        '/synastry': (_) => const SynastryIntroScreen(),

        // ✅ Debug route
        '/iap-debug': (_) => const IapDebugScreen(),
      },
    );
  }
}
