import 'package:flutter/material.dart';
import 'app_colors.dart';

class _MysticPageTransitionsBuilder extends PageTransitionsBuilder {
  const _MysticPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.035),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: child,
      ),
    );
  }
}

class AppTheme {
  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _MysticPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: _MysticPageTransitionsBuilder(),
          TargetPlatform.linux: _MysticPageTransitionsBuilder(),
          TargetPlatform.macOS: _MysticPageTransitionsBuilder(),
        },
      ),

      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.gold,
        secondary: AppColors.goldSoft,
        surface: Colors.black,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: false,
      ),

      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.black.withOpacity(0.40),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.80)),
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.55)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.2),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          textStyle: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.3),
          overlayColor: AppColors.gold.withOpacity(0.25),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.black.withOpacity(0.22),
          side: BorderSide(color: AppColors.gold.withOpacity(0.65), width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.3),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),

      // ✅ Flutter 3.9+ için doğru tip: CardThemeData
      cardTheme: CardThemeData(
        color: Colors.black.withOpacity(0.22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // Tarih seçici: koyu arka plan, altın vurgu, takvim grid (Tarih seçin / İptal / Tamam)
      datePickerTheme: DatePickerThemeData(
        backgroundColor: const Color(0xFF2C2C3E),
        headerBackgroundColor: const Color(0xFF1E1E2E),
        headerForegroundColor: AppColors.gold,
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.black;
          return Colors.white;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.gold;
          return null;
        }),
        weekdayStyle: TextStyle(color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w600),
        dayStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        yearStyle: TextStyle(color: Colors.white.withOpacity(0.9)),
        cancelButtonStyle: TextButton.styleFrom(foregroundColor: AppColors.gold),
        confirmButtonStyle: TextButton.styleFrom(foregroundColor: AppColors.gold),
        locale: const Locale('tr', 'TR'),
      ),

      // Saat seçici: koyu arka plan, altın kadran/ok, Saat seçin / İptal / Tamam
      timePickerTheme: TimePickerThemeData(
        backgroundColor: const Color(0xFF2C2C3E),
        dialBackgroundColor: const Color(0xFF1E1E2E),
        dialHandColor: AppColors.gold,
        dialTextColor: Colors.white,
        hourMinuteColor: AppColors.gold.withOpacity(0.25),
        hourMinuteTextColor: Colors.white,
        dayPeriodColor: AppColors.gold.withOpacity(0.2),
        cancelButtonStyle: TextButton.styleFrom(foregroundColor: AppColors.gold),
        confirmButtonStyle: TextButton.styleFrom(foregroundColor: AppColors.gold),
        helpTextStyle: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w600),
      ),
    );
  }
}
