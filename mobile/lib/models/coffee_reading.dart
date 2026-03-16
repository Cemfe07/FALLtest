// mobile/lib/models/coffee_reading.dart
class CoffeeReading {
  final String id;
  final String name;
  final int? age;
  final String topic;
  final String question;
  final List<String> photos;
  final String status;
  final bool hasResult;

  // ✅ yorum
  final String? comment;

  final int? rating;
  final String? paymentRef;
  final String createdAt;

  CoffeeReading({
    required this.id,
    required this.name,
    required this.age,
    required this.topic,
    required this.question,
    required this.photos,
    required this.status,
    required this.hasResult,
    required this.comment,
    required this.rating,
    required this.paymentRef,
    required this.createdAt,
  });

  factory CoffeeReading.fromJson(Map<String, dynamic> j) {
    final photos =
        (j['photos'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];

    // ✅ backend comment veya result_text dönebilir
    final rawComment = (j['comment'] ?? j['result_text'])?.toString();
    final comment =
        (rawComment != null && rawComment.trim().isNotEmpty) ? rawComment : null;

    return CoffeeReading(
      id: j['id'].toString(),
      name: (j['name'] ?? '').toString(),
      age: j['age'] == null ? null : int.tryParse(j['age'].toString()),
      topic: (j['topic'] ?? '').toString(),
      question: (j['question'] ?? '').toString(),
      photos: photos,
      status: (j['status'] ?? '').toString(),
      hasResult: (j['has_result'] ?? false) == true,
      comment: comment,
      rating: j['rating'] == null ? null : int.tryParse(j['rating'].toString()),
      paymentRef: (j['payment_ref'] ?? j['paymentRef'])?.toString(),
      createdAt: (j['created_at'] ?? j['createdAt'] ?? '').toString(),
    );
  }
}
