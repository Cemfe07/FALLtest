/// Günün manifesti: Tarihe göre deterministik, her gün farklı bir manifest/olumlama cümlesi.
class DailyManifestService {
  static const List<String> _manifests = [
    'Bugün bolluk ve bereket benimle.',
    'Kendime güveniyor ve sevgiyle davranıyorum.',
    'Evren bana ihtiyacım olan her şeyi sunuyor.',
    'Sağlıklı, güçlü ve huzurluyum.',
    'Yeni fırsatlar kapımı çalıyor.',
    'İçimdeki ışık her gün daha parlak.',
    'Geçmişi bırakıyor, şimdiye odaklanıyorum.',
    'Sevgi ve şükranla doluyum.',
    'Her nefes beni güçlendiriyor.',
    'Hayallerim gerçeğe dönüşüyor.',
    'Korkularımdan özgürleşiyorum.',
    'Başarı ve refah benim doğal hakkım.',
    'İlişkilerim sevgi ve saygıyla gelişiyor.',
    'Bugün mucizelere açığım.',
    'Kaderim benim ellerimde.',
    'Sakinlik ve dinginlik benimle.',
    'Yaratıcı enerjim sınırsız.',
    'Kendimi olduğum gibi kabul ediyorum.',
    'Niyetim net; evren bana yanıt veriyor.',
    'Bugün cesur adımlar atıyorum.',
    'Şükran dolu bir kalple uyuyorum.',
    'Enerjim yüksek; odaklanmışım.',
    'Sevgiyi vermeye ve almaya hazırım.',
    'İç sesim bana doğru yolu gösteriyor.',
    'Değişime açığım ve büyüyorum.',
    'Bugün kendime iyi davranıyorum.',
    'Abundans (bolluk) benim doğal halim.',
    'Geleceğim parlak; bugün onu inşa ediyorum.',
  ];

  /// Bugünün manifesti (tarih bazlı, aynı gün her zaman aynı).
  static String get manifest {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    final index = dayOfYear % _manifests.length;
    return _manifests[index];
  }

  /// Kart etiketi.
  static const String label = 'Günün manifesti';
}
