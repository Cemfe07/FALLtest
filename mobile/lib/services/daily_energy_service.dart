/// "Günün enerjisi" – seçilen ruh hali için kısa motivasyon mesajı.
class DailyEnergyService {
  static const Map<String, List<String>> _messages = {
    'Enerjik': [
      'Enerjin yüksek! Bugün bir hedefe küçük bir adım at.',
      'Hareket ruhu besler. Kısa bir yürüyüş bile iyi gelir.',
      'Cesur adımlar bugün seni ileri taşır.',
    ],
    'Sakin': [
      'Sakin kalmak da bir güç. Nefesine odaklan.',
      'Yavaşlamak bazen en hızlı ilerleyişidir.',
      'Bugün kendine yumuşak davran.',
    ],
    'Meraklı': [
      'Merak zihni açar. Bugün yeni bir şey öğren.',
      'Sorular sormak, cevaplardan bazen daha değerli.',
      'Keşfetmeye açık ol; evren detaylarda saklı.',
    ],
    'Romantik': [
      'Sevgi enerjisi yüksek. Birine minnetini söyle.',
      'Kendini de sev; önce sen, sonra başkaları.',
      'Küçük bir sürpriz bugün ilişkilere iyi gelir.',
    ],
  };

  /// Seçilen enerji için mesaj (tarih bazlı, aynı gün aynı).
  static String getMessage(String energyKey) {
    final list = _messages[energyKey];
    if (list == null || list.isEmpty) return 'Bugün kendini dinle.';
    final now = DateTime.now();
    final seed = now.day + now.month * 31 + energyKey.hashCode;
    return list[seed.abs() % list.length];
  }

  static List<String> get energyKeys => ['Enerjik', 'Sakin', 'Meraklı', 'Romantik'];
}
