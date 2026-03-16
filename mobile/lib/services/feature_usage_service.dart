import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Haftalık açılış sayılarına göre "en çok kullanılan" analizi döndürür.
class FeatureUsageService {
  static const _key = 'feature_usage';
  static const _maxDays = 7;

  /// Açılış kaydı: [featureId, timestampMs, ...] (son 7 gün tutulur).
  static Future<void> recordOpen(String featureId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    final List<dynamic> list = raw != null ? jsonDecode(raw) as List<dynamic> : [];
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: _maxDays));
    final entries = <List<dynamic>>[];
    for (final e in list) {
      if (e is! List || e.length < 2) continue;
      final ts = e[1] is int ? e[1] as int : (e[1] as num).toInt();
      if (DateTime.fromMillisecondsSinceEpoch(ts).isAfter(cutoff)) {
        entries.add([e[0], ts]);
      }
    }
    entries.add([featureId, now.millisecondsSinceEpoch]);
    await prefs.setString(_key, jsonEncode(entries));
  }

  /// Son 7 günde en çok açılan feature id (eşitlikte ilk bulunan).
  static Future<String?> getMostUsedThisWeek() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    final list = jsonDecode(raw) as List<dynamic>?;
    if (list == null || list.isEmpty) return null;
    final cutoff = DateTime.now().subtract(const Duration(days: _maxDays));
    final counts = <String, int>{};
    for (final e in list) {
      if (e is! List || e.length < 2) continue;
      final id = e[0] as String? ?? '';
      final ts = e[1] is int ? e[1] as int : (e[1] as num).toInt();
      if (DateTime.fromMillisecondsSinceEpoch(ts).isAfter(cutoff) && id.isNotEmpty) {
        counts[id] = (counts[id] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return null;
    String? maxId;
    int maxCount = 0;
    counts.forEach((id, count) {
      if (count > maxCount) {
        maxCount = count;
        maxId = id;
      }
    });
    return maxId;
  }
}
