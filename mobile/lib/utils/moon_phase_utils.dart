/// Basit ay evresi hesabı (tarihe göre) + Türkçe etiket.
class MoonPhaseUtils {
  /// Yaklaşık ay evresi: 0 = yeni ay, 0.25 = ilk dördün, 0.5 = dolunay, 0.75 = son dördün.
  static double phaseFromDate(DateTime date) {
    // Basit döngü: ~29.53 gün (lunar cycle)
    const cycleDays = 29.530588853;
    final knownNewMoon = DateTime(2000, 1, 6);
    final diff = date.difference(knownNewMoon).inDays;
    final cycle = (diff % cycleDays) / cycleDays;
    return cycle;
  }

  static String label(double phase) {
    if (phase < 0.03 || phase >= 0.97) return 'Yeni Ay';
    if (phase < 0.22) return 'Hilal';
    if (phase < 0.28) return 'İlk Dördün';
    if (phase < 0.47) return 'Şişkin Ay';
    if (phase < 0.53) return 'Dolunay';
    if (phase < 0.72) return 'Şişkin Ay';
    if (phase < 0.78) return 'Son Dördün';
    if (phase < 0.97) return 'Hilal';
    return 'Yeni Ay';
  }

  static String shortMeaning(String phaseLabel) {
    switch (phaseLabel) {
      case 'Yeni Ay':
        return 'Yeni başlangıçlar için uygun enerji.';
      case 'Hilal':
        return 'Büyüme ve niyet belirleme zamanı.';
      case 'İlk Dördün':
        return 'Eylem ve ilerleme vurgusu.';
      case 'Şişkin Ay':
        return 'Olgunlaşma ve netleşme.';
      case 'Dolunay':
        return 'Tamamlanma ve kutlama enerjisi.';
      case 'Son Dördün':
        return 'Bırakma ve özet çıkarma.';
      default:
        return 'Ay döngüsü ruh halini etkiler.';
    }
  }

  /// Bugünün ay evresi etiketi.
  static String get todayLabel => label(phaseFromDate(DateTime.now()));
  static String get todayMeaning => shortMeaning(todayLabel);
}
