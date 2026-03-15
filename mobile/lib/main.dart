import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:device_preview/device_preview.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'core/app_theme.dart';
import 'features/home/home_screen.dart';
import 'features/legal/legal_consent_gate_screen.dart';

// ✅ Synastry
import 'features/synastry/synastry_intro_screen.dart';

// ✅ IAP Debug Screen
import 'features/iap/iap_debug_screen.dart';

// ✅ IAP service
import 'services/iap_service.dart';
// ✅ Push: yorum hazır bildirimi
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

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

    // ✅ Purchase stream subscription varsa temizle
    IapService.instance.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

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
