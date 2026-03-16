/// Doğum tarihinden burç hesaplar; Türkçe isim ve sembol döner.
class ZodiacUtils {
  /// YYYY-MM-DD veya benzeri (ay ve gün kullanılır).
  static String? getSignFromBirthDate(String? birthDate) {
    if (birthDate == null || birthDate.trim().isEmpty) return null;
    final parts = birthDate.trim().split(RegExp(r'[-/.\s]'));
    if (parts.length < 2) return null;
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts.length >= 3 ? parts[2] : parts[0]);
    if (month == null || day == null) return null;
    return getSignFromMonthDay(month, day);
  }

  static String? getSignFromMonthDay(int month, int day) {
    if (month == 1) return day < 20 ? 'Oğlak' : 'Kova';
    if (month == 2) return day < 19 ? 'Kova' : 'Balık';
    if (month == 3) return day < 21 ? 'Balık' : 'Koç';
    if (month == 4) return day < 20 ? 'Koç' : 'Boğa';
    if (month == 5) return day < 21 ? 'Boğa' : 'İkizler';
    if (month == 6) return day < 21 ? 'İkizler' : 'Yengeç';
    if (month == 7) return day < 23 ? 'Yengeç' : 'Aslan';
    if (month == 8) return day < 23 ? 'Aslan' : 'Başak';
    if (month == 9) return day < 23 ? 'Başak' : 'Terazi';
    if (month == 10) return day < 23 ? 'Terazi' : 'Akrep';
    if (month == 11) return day < 22 ? 'Akrep' : 'Yay';
    if (month == 12) return day < 22 ? 'Yay' : 'Oğlak';
    return null;
  }

  /// Burç sembolü (emoji).
  static String symbol(String? sign) {
    if (sign == null) return '✨';
    switch (sign) {
      case 'Koç': return '♈';
      case 'Boğa': return '♉';
      case 'İkizler': return '♊';
      case 'Yengeç': return '♋';
      case 'Aslan': return '♌';
      case 'Başak': return '♍';
      case 'Terazi': return '♎';
      case 'Akrep': return '♏';
      case 'Yay': return '♐';
      case 'Oğlak': return '♑';
      case 'Kova': return '♒';
      case 'Balık': return '♓';
      default: return '✨';
    }
  }
}
