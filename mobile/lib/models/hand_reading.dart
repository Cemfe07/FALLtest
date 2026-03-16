// mobile/lib/models/hand_reading.dart
class HandReading {
  final String id;
  final String topic;
  final String question;
  final String name;
  final int? age;

  final String? dominantHand;
  final String? photoHand;
  final String status;
  final bool hasResult;
  final List<String> photos;

  final String? comment;
  final String? resultText;

  final bool isPaid;
  final String? paymentRef;
  final int? rating;

  HandReading({
    required this.id,
    required this.topic,
    required this.question,
    required this.name,
    required this.age,
    required this.dominantHand,
    required this.photoHand,
    required this.status,
    required this.hasResult,
    required this.photos,
    required this.comment,
    required this.resultText,
    required this.isPaid,
    required this.paymentRef,
    required this.rating,
  });

  factory HandReading.fromJson(Map<String, dynamic> j) {
    return HandReading(
      id: j['id'] as String,
      topic: (j['topic'] ?? '') as String,
      question: (j['question'] ?? '') as String,
      name: (j['name'] ?? '') as String,
      age: j['age'] as int?,
      dominantHand: j['dominant_hand'] as String?,
      photoHand: j['photo_hand'] as String?,
      status: (j['status'] ?? '') as String,
      hasResult: (j['has_result'] ?? false) == true,
      photos: ((j['photos'] ?? []) as List).map((e) => e.toString()).toList(),
      comment: j['comment'] as String?,
      resultText: j['result_text'] as String?,
      isPaid: (j['is_paid'] ?? false) as bool,
      paymentRef: j['payment_ref'] as String?,
      rating: j['rating'] as int?,
    );
  }
}
