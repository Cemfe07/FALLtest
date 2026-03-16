// lib/models/synastry_models.dart
import 'dart:convert';

String _s(dynamic v, [String def = '']) => (v == null) ? def : v.toString();

bool _b(dynamic v, [bool def = false]) {
  if (v == null) return def;
  if (v is bool) return v;
  final t = v.toString().toLowerCase().trim();
  if (t == 'true' || t == '1' || t == 'yes') return true;
  if (t == 'false' || t == '0' || t == 'no') return false;
  return def;
}

int? _i(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  return int.tryParse(v.toString());
}

double? _d(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

/// ------------------------------
/// START REQUEST/RESPONSE
/// ------------------------------
class SynastryStartRequest {
  final String nameA;
  final String birthDateA;
  final String? birthTimeA;
  final String birthCityA;
  final String birthCountryA;

  final String nameB;
  final String birthDateB;
  final String? birthTimeB;
  final String birthCityB;
  final String birthCountryB;

  final String topic;
  final String? question;

  SynastryStartRequest({
    required this.nameA,
    required this.birthDateA,
    this.birthTimeA,
    required this.birthCityA,
    this.birthCountryA = 'TR',
    required this.nameB,
    required this.birthDateB,
    this.birthTimeB,
    required this.birthCityB,
    this.birthCountryB = 'TR',
    this.topic = 'genel',
    this.question,
  });

  Map<String, dynamic> toJson() => {
        "name_a": nameA,
        "birth_date_a": birthDateA,
        "birth_time_a": birthTimeA,
        "birth_city_a": birthCityA,
        "birth_country_a": birthCountryA,
        "name_b": nameB,
        "birth_date_b": birthDateB,
        "birth_time_b": birthTimeB,
        "birth_city_b": birthCityB,
        "birth_country_b": birthCountryB,
        "topic": topic,
        "question": question,
      };
}

class SynastryStartResponse {
  final String readingId;
  final String status;
  final bool isPaid;

  SynastryStartResponse({
    required this.readingId,
    required this.status,
    required this.isPaid,
  });

  factory SynastryStartResponse.fromJson(Map<String, dynamic> j) {
    // backend: reading_id
    final rid = _s(j["reading_id"] ?? j["readingId"] ?? j["id"]);
    final st = _s(j["status"], "started");
    final paid = _b(j["is_paid"] ?? j["isPaid"], false);

    if (rid.isEmpty) {
      throw FormatException("SynastryStartResponse reading_id boş geldi: ${jsonEncode(j)}");
    }
    return SynastryStartResponse(readingId: rid, status: st, isPaid: paid);
  }
}

/// ------------------------------
/// MARK PAID (legacy)
/// ------------------------------
class SynastryMarkPaidRequest {
  final String? paymentRef;
  SynastryMarkPaidRequest({this.paymentRef});

  Map<String, dynamic> toJson() => {"payment_ref": paymentRef};
}

/// ------------------------------
/// STATUS RESPONSE
/// ------------------------------
class SynastryStatusResponse {
  final String readingId;
  final String status;
  final bool isPaid;
  final bool hasResult;
  final String? resultText;
  final int? rating;
  final String? paymentRef;

  // UI için opsiyonel bir error alanı (backend’de yoksa null)
  final String? error;

  SynastryStatusResponse({
    required this.readingId,
    required this.status,
    required this.isPaid,
    required this.hasResult,
    this.resultText,
    this.rating,
    this.paymentRef,
    this.error,
  });

  factory SynastryStatusResponse.fromJson(Map<String, dynamic> j) {
    final rid = _s(j["reading_id"] ?? j["readingId"] ?? j["id"]);
    final st = _s(j["status"], "");
    final paid = _b(j["is_paid"] ?? j["isPaid"], false);
    final hasResult = _b(j["has_result"] ?? j["hasResult"], false);

    final rt = _s(j["result_text"] ?? j["resultText"], "").trim();
    final pr = _s(j["payment_ref"] ?? j["paymentRef"], "").trim();

    // bazı backend’ler hata mesajını detail veya error döndürebilir
    final err = _s(j["error"] ?? j["detail"], "").trim();
    final errVal = err.isEmpty ? null : err;

    if (rid.isEmpty) {
      throw FormatException("SynastryStatusResponse reading_id boş geldi: ${jsonEncode(j)}");
    }

    return SynastryStatusResponse(
      readingId: rid,
      status: st,
      isPaid: paid,
      hasResult: hasResult,
      resultText: rt.isEmpty ? null : rt,
      rating: _i(j["rating"]),
      paymentRef: pr.isEmpty ? null : pr,
      error: errVal,
    );
  }
}

/// ------------------------------
/// RATING REQUEST
/// ------------------------------
class SynastryRatingRequest {
  final int rating; // 1..5
  SynastryRatingRequest({required this.rating});

  Map<String, dynamic> toJson() => {"rating": rating};
}
