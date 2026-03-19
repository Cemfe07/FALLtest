import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api_base.dart';
import '../models/profile_models.dart';

String _extractErrorMessage(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      final detail = decoded['detail'];
      if (detail is String && detail.trim().isNotEmpty) return detail;
      return decoded.toString();
    }
  } catch (_) {}
  return body;
}

class ProfileApi {
  static Uri _u(String path) => Uri.parse('${ApiBase.baseUrl}$path');

  static Future<ProfileMe> getMe({required String deviceId}) async {
    final res = await http
        .get(_u('/profile/me'), headers: ApiBase.headers(deviceId: deviceId))
        .timeout(const Duration(seconds: 30));

    if (res.statusCode >= 400) {
      throw Exception("profile/me GET failed: ${res.statusCode} / ${_extractErrorMessage(res.body)}");
    }
    return ProfileMe.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<ProfileMe> upsertMe({
    required String deviceId,
    required ProfileUpsertRequest req,
  }) async {
    final res = await http
        .post(
          _u('/profile/me'),
          headers: ApiBase.headers(deviceId: deviceId),
          body: jsonEncode(req.toJson()),
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode >= 400) {
      throw Exception("profile/me POST failed: ${res.statusCode} / ${_extractErrorMessage(res.body)}");
    }
    return ProfileMe.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Son N okumayı getirir (tüm türler karışık, tarihe göre azalan).
  static Future<ProfileHistoryResponse> getHistory({
    required String deviceId,
    int limit = 20,
  }) async {
    final limitClamped = limit.clamp(1, 100);
    final res = await http
        .get(
          Uri.parse('${ApiBase.baseUrl}/profile/history?limit=$limitClamped&offset=0'),
          headers: ApiBase.headers(deviceId: deviceId),
        )
        .timeout(const Duration(seconds: 25));

    if (res.statusCode >= 400) {
      throw Exception("profile/history GET failed: ${res.statusCode} / ${_extractErrorMessage(res.body)}");
    }
    return ProfileHistoryResponse.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
