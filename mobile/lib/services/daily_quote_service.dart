/// Günün sözü: Tarihe göre deterministik, her gün aynı söz.
class DailyQuoteService {
  static const List<String> _quotes = [
    'İçindeki cevheri keşfetmek için ilk adımı at.',
    'Yıldızlar yalnızca karanlıkta parlar.',
    'Kaderin, senin seçimlerinle şekillenir.',
    'Bugün dünün yarınıdır; anı yaşa.',
    'Sezgilerin çoğu zaman doğruyu söyler.',
    'Değişim, büyümenin kapısıdır.',
    'Her gün yeni bir sayfa; sen yazarsın.',
    'Sakinlik, gücün sessiz dilidir.',
    'Kendine inan, evren seninle.',
    'Küçük adımlar büyük yolculukları başlatır.',
    'Enerjin nereye giderse, hayatın orada açılır.',
    'Geçmiş ders, gelecek umut; şimdi hediyedir.',
    'İç sesin rehberindir; dinle.',
    'Merak, bilgeliğin anahtarıdır.',
    'Her son bir başlangıçtır.',
    'Rüyaların peşinden git; evren yardım eder.',
    'Sabır ve inanç, sihrin formülüdür.',
    'Kendinle barışık ol; dünya seni takip eder.',
    'Bugünkü niyetin yarının gerçeğidir.',
    'Yıldız haritan seninle konuşuyor; dinle.',
  ];

  /// Bugünün sözü (tarih bazlı, aynı gün her zaman aynı).
  static String get quote {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    final index = dayOfYear % _quotes.length;
    return _quotes[index];
  }

  /// Günün kartı için kısa etiket (opsiyonel kullanım).
  static String get cardLabel {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    const labels = ['Işığın kartı', 'Yolcu kartı', 'Denge kartı', 'Sevgi kartı', 'Bilgelik kartı'];
    return labels[dayOfYear % labels.length];
  }
}
