class NumerologyReading {
  final String id;
  final String topic;
  final String? question;
  final String name;
  final String birthDate;
  final String status;
  final bool hasResult;
  final String? resultText;
  final bool isPaid;
  final String? paymentRef;

  NumerologyReading({
    required this.id,
    required this.topic,
    required this.question,
    required this.name,
    required this.birthDate,
    required this.status,
    required this.hasResult,
    required this.resultText,
    required this.isPaid,
    required this.paymentRef,
  });

  factory NumerologyReading.fromJson(Map<String, dynamic> j) {
    return NumerologyReading(
      id: (j["id"] ?? "").toString(),
      topic: (j["topic"] ?? "genel").toString(),
      question: j["question"]?.toString(),
      name: (j["name"] ?? "").toString(),
      birthDate: (j["birth_date"] ?? "").toString(),
      status: (j["status"] ?? "").toString(),
      hasResult: (j["has_result"] ?? false) == true,
      resultText: j["result_text"]?.toString(),
      isPaid: (j["is_paid"] ?? false) == true,
      paymentRef: j["payment_ref"]?.toString(),
    );
  }
}
