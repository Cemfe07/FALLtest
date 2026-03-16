/// Günlük burç yorumu: tarih + burca göre deterministik kısa mesaj.
class DailyHoroscopeService {
  static const Map<String, List<String>> _messages = {
    'Koç': [
      'Bugün cesaretin ve enerjin yüksek. Yeni adımlar için uygun bir gün.',
      'İletişim ve işbirliği öne çıkıyor. Dinlemeye zaman ayır.',
      'Yaratıcı fikirler gelişebilir. Not al, sonra uygula.',
      'Sakin kalmak seni bugün ileri taşır.',
    ],
    'Boğa': [
      'Topraklanma ve güvenlik hissi güçlü. Küçük ritüeller iyi gelir.',
      'Maddi konularda netlik kazanabilirsin.',
      'Sevdiklerinle kaliteli zaman bugün şans getirir.',
      'Sabırlı ol; meyveler biraz sonra toplanır.',
    ],
    'İkizler': [
      'Merak ve iletişim günü. Yeni bir şey öğrenmek için iyi zaman.',
      'Fikirler hızlı akıyor; en iyisini seçip odaklan.',
      'Kısa bir sohbet bile ruh halini yükseltebilir.',
      'Hafiflik ve esneklik bugün anahtar.',
    ],
    'Yengeç': [
      'Duygusal derinlik ve sezgi güçlü. İç sesini dinle.',
      'Ev ve aile enerjisi öne çıkıyor.',
      'Kendine nazik davran; dinlenmek de üretmektir.',
      'Küçük bir iyilik bugün çok şey değiştirebilir.',
    ],
    'Aslan': [
      'Özgüven ve yaratıcılık yüksek. Kendini ifade et.',
      'Liderlik ve cömertlik bugün seni öne çıkarır.',
      'Pozitif enerji çevrene yayılır.',
      'Küçük bir risk almak iyi sonuç verebilir.',
    ],
    'Başak': [
      'Detaylara dikkat ve düzen bugün faydalı.',
      'Sağlıklı alışkanlıklar ve rutinler öne çıkıyor.',
      'Yardım etmek hem seni hem başkalarını iyi hissettirir.',
      'Mükemmellik değil, ilerleme hedefle.',
    ],
    'Terazi': [
      'Denge ve uyum arayışı güçlü. Adil kararlar için iyi gün.',
      'İlişkiler ve ortaklıklar öne çıkıyor.',
      'Güzellik ve estetik seni iyi hissettirir.',
      'Dinle ve tart; acele etme.',
    ],
    'Akrep': [
      'Sezgi ve dönüşüm enerjisi yüksek. Derinlere bak.',
      'Gizlilik ve strateji bugün güçlü yanların.',
      'Eski bir konuyu kapatmak için uygun zaman.',
      'Güven inşa et; kendine ve çevrene.',
    ],
    'Yay': [
      'Özgürlük ve keşif arzusu güçlü. Yeni bir şey denemek iyi gelir.',
      'İyimserlik ve macera bugün seninle.',
      'Uzun vadeli planlara kısa bir adım at.',
      'Mizah ve hafiflik ruh halini yükseltir.',
    ],
    'Oğlak': [
      'Disiplin ve hedef odaklılık güçlü. Küçük ilerlemeler sayılır.',
      'Sorumluluk almak bugün saygı getirir.',
      'Sabırla ilerle; zirve bir günde çıkılmaz.',
      'Güvenilir olmak bugün en büyük sermaye.',
    ],
    'Kova': [
      'Yenilik ve topluluk enerjisi yüksek. Farklı fikirlere açık ol.',
      'Dostluk ve işbirliği bugün öne çıkıyor.',
      'Hayal et; sonra adım adım gerçekleştir.',
      'Özgün kalmak seni bugün güçlü kılar.',
    ],
    'Balık': [
      'Sezgi ve hayal gücü güçlü. Yaratıcı veya spiritüel bir an kendine ayır.',
      'Empati ve anlayış bugün senin dilin.',
      'Sınırları korumak da sevgi göstermektir.',
      'Küçük bir kaçış (kitap, müzik) ruhu besler.',
    ],
  };

  /// Bugünkü kısa burç mesajı (burç + tarih bazlı).
  static String getDailyMessage(String? sign) {
    if (sign == null || sign.isEmpty) return 'Doğum tarihini Profil\'e ekleyerek burcunu ve günlük yorumunu görebilirsin.';
    final list = _messages[sign];
    if (list == null || list.isEmpty) return 'Bugün iç sesini dinle.';
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    final index = dayOfYear % list.length;
    return list[index];
  }
}
