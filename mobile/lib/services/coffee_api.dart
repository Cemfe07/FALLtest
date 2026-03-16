import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../models/coffee_reading.dart';
import 'api_base.dart';
import 'device_id_service.dart';

/// ✅ Tipli hata: UI tarafı statusCode'a göre mesaj gösterebilsin
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String endpoint;
  final String? rawBody;

  ApiException({
    required this.statusCode,
    required this.message,
    required this.endpoint,
    this.rawBody,
  });

  @override
  String toString() => '$endpoint failed: $statusCode / $message';
}

class CoffeeApi {
  static String get _base => ApiBase.baseUrl;

  static const Duration _defaultTimeout = Duration(seconds: 30);
  static const Duration _uploadTimeout = Duration(seconds: 90);
  static const Duration _generateTimeout = Duration(seconds: 150);

  static String _extractErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);

      // FastAPI standard: {"detail": "..."} veya {"detail": {"...": ...}}
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];

        if (detail is String && detail.trim().isNotEmpty) return detail.trim();
        if (detail != null) return detail.toString();

        // fallback: error alanı varsa
        final err = decoded['error'];
        if (err != null) return err.toString();

        return decoded.toString();
      }

      return decoded.toString();
    } catch (_) {
      // body JSON değilse düz string
      final t = body.trim();
      return t.isEmpty ? 'Unknown error' : t;
    }
  }

  static Future<String> _resolveDeviceId(String? deviceId) async {
    final d = (deviceId ?? '').trim();
    if (d.isNotEmpty) return d;
    return await DeviceIdService.getOrCreate();
  }

  static Never _throwApi(String endpoint, http.Response res) {
    final msg = _extractErrorMessage(res.body);
    throw ApiException(
      statusCode: res.statusCode,
      message: msg,
      endpoint: endpoint,
      rawBody: res.body,
    );
  }

  static Future<CoffeeReading> start({
    required String name,
    int? age,
    required String topic,
    required String question,
    String? relationshipStatus,
    String? bigDecision,
    String? deviceId,
  }) async {
    final did = await _resolveDeviceId(deviceId);

    final uri = Uri.parse('$_base/coffee/start');
    final body = {
      "name": name,
      "age": age,
      "topic": topic,
      "question": question,
      "relationship_status": relationshipStatus,
      "big_decision": bigDecision,
    };

    final res = await http
        .post(
          uri,
          headers: ApiBase.headers(deviceId: did),
          body: jsonEncode(body),
        )
        .timeout(_defaultTimeout);

    if (res.statusCode != 200) {
      _throwApi('coffee/start', res);
    }

    return CoffeeReading.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<CoffeeReading> uploadImages({
    required String readingId,
    required List<XFile> files,
    String? deviceId,
  }) async {
    final did = await _resolveDeviceId(deviceId);

    final uri = Uri.parse('$_base/coffee/$readingId/upload-images');
    final req = http.MultipartRequest('POST', uri);

    // ✅ device id header
    req.headers.addAll({
      "Accept": "application/json",
      "X-Device-Id": did,
    });

    for (final f in files) {
      final bytes = await f.readAsBytes();
      final filename = f.path.split('/').last.split('\\').last;
      req.files.add(
        http.MultipartFile.fromBytes(
          'files',
          bytes,
          filename: filename.isEmpty ? 'upload.jpg' : filename,
        ),
      );
    }

    final streamed = await req.send().timeout(_uploadTimeout);
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode != 200) {
      _throwApi('coffee/upload-images', res);
    }

    return CoffeeReading.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<CoffeeReading> uploadPhotos({
    required String readingId,
    List<XFile>? files,
    List<XFile>? imageFiles,
    String? deviceId,
  }) {
    final chosen = (files != null && files.isNotEmpty) ? files : (imageFiles ?? <XFile>[]);
    if (chosen.isEmpty) {
      throw ApiException(
        statusCode: 0,
        message: 'Foto seçilmedi.',
        endpoint: 'coffee/upload-photos',
      );
    }
    return uploadImages(readingId: readingId, files: chosen, deviceId: deviceId);
  }

  /// ✅ LEGACY: mock akış için (TEST-...)
  static Future<CoffeeReading> markPaid({
    required String readingId,
    String? paymentRef,
    String? deviceId,
  }) async {
    final did = await _resolveDeviceId(deviceId);

    final ref = (paymentRef ?? '').trim();
    if (ref.isNotEmpty && !ref.startsWith("TEST-")) {
      throw ApiException(
        statusCode: 400,
        message: "markPaid legacy only. Real payments use /payments/verify.",
        endpoint: 'coffee/mark-paid',
      );
    }

    final uri = Uri.parse('$_base/coffee/$readingId/mark-paid');

    final res = await http
        .post(
          uri,
          headers: ApiBase.headers(deviceId: did),
          body: jsonEncode({"payment_ref": paymentRef}),
        )
        .timeout(_defaultTimeout);

    if (res.statusCode != 200) {
      _throwApi('coffee/mark-paid', res);
    }

    return CoffeeReading.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<CoffeeReading> generate({
    required String readingId,
    String? deviceId,
  }) async {
    final did = await _resolveDeviceId(deviceId);

    final uri = Uri.parse('$_base/coffee/$readingId/generate');

    final res = await http
        .post(
          uri,
          headers: ApiBase.headers(deviceId: did),
        )
        .timeout(_generateTimeout);

    if (res.statusCode != 200) {
      _throwApi('coffee/generate', res);
    }

    return CoffeeReading.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<CoffeeReading> detail({
    required String readingId,
    String? deviceId,
  }) async {
    final did = await _resolveDeviceId(deviceId);

    final uri = Uri.parse('$_base/coffee/$readingId');

    final res = await http
        .get(
          uri,
          headers: ApiBase.headers(deviceId: did),
        )
        .timeout(_defaultTimeout);

    if (res.statusCode != 200) {
      _throwApi('coffee/detail', res);
    }

    return CoffeeReading.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<Map<String, dynamic>> detailRaw({
    required String readingId,
    String? deviceId,
  }) async {
    final did = await _resolveDeviceId(deviceId);

    final uri = Uri.parse('$_base/coffee/$readingId');

    final res = await http
        .get(
          uri,
          headers: ApiBase.headers(deviceId: did),
        )
        .timeout(_defaultTimeout);

    if (res.statusCode != 200) {
      _throwApi('coffee/detail', res);
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<CoffeeReading> rate({
    required String readingId,
    required int rating,
    String? deviceId,
  }) async {
    final did = await _resolveDeviceId(deviceId);

    final uri = Uri.parse('$_base/coffee/$readingId/rate');

    final res = await http
        .post(
          uri,
          headers: ApiBase.headers(deviceId: did),
          body: jsonEncode({"rating": rating}),
        )
        .timeout(_defaultTimeout);

    if (res.statusCode != 200) {
      _throwApi('coffee/rate', res);
    }

    return CoffeeReading.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
