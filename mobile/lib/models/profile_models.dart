class ProfileMe {
  final String deviceId;
  final String displayName;
  final String? birthDate;
  final String? birthPlace;
  final String? birthTime;

  ProfileMe({
    required this.deviceId,
    required this.displayName,
    this.birthDate,
    this.birthPlace,
    this.birthTime,
  });

  factory ProfileMe.fromJson(Map<String, dynamic> json) {
    return ProfileMe(
      deviceId: (json['device_id'] ?? '').toString(),
      displayName: (json['display_name'] ?? 'Misafir').toString(),
      birthDate: json['birth_date']?.toString(),
      birthPlace: json['birth_place']?.toString(),
      birthTime: json['birth_time']?.toString(),
    );
  }
}

class ProfileUpsertRequest {
  final String displayName;
  final String? birthDate;
  final String? birthPlace;
  final String? birthTime;

  ProfileUpsertRequest({
    required this.displayName,
    this.birthDate,
    this.birthPlace,
    this.birthTime,
  });

  Map<String, dynamic> toJson() {
    return {
      "display_name": displayName,
      "birth_date": (birthDate ?? '').trim().isEmpty ? null : birthDate!.trim(),
      "birth_place": (birthPlace ?? '').trim().isEmpty ? null : birthPlace!.trim(),
      "birth_time": (birthTime ?? '').trim().isEmpty ? null : birthTime!.trim(),
    };
  }
}

/// Profil "Benim Okumalarım" için tek okuma öğesi (backend ProfileActivityItem)
class ProfileReadingItem {
  final String type;
  final String id;
  final String title;
  final String status;
  final bool isPaid;
  /// Backend'den gelir: metin kilitli olsa da yorum üretimi tamamlandı mı?
  final bool hasResult;
  final DateTime? createdAt;
  /// Ödenmiş okumalarda yorum metni (profilde gösterilir)
  final String? resultText;

  ProfileReadingItem({
    required this.type,
    required this.id,
    required this.title,
    required this.status,
    required this.isPaid,
    required this.hasResult,
    this.createdAt,
    this.resultText,
  });

  factory ProfileReadingItem.fromJson(Map<String, dynamic> json) {
    DateTime? createdAt;
    final raw = json['created_at'];
    if (raw != null) {
      if (raw is String) {
        createdAt = DateTime.tryParse(raw);
      }
    }
    final rt = json['result_text'];
    final resultText = (rt != null && rt.toString().trim().isNotEmpty)
        ? rt.toString().trim()
        : null;
    return ProfileReadingItem(
      type: (json['type'] ?? '').toString(),
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      isPaid: json['is_paid'] == true,
      hasResult: json['has_result'] == true,
      createdAt: createdAt,
      resultText: resultText,
    );
  }

  String get typeLabel {
    switch (type) {
      case 'coffee':
        return 'Kahve Falı';
      case 'hand':
        return 'El Falı';
      case 'tarot':
        return 'Tarot';
      case 'numerology':
        return 'Numeroloji';
      case 'birthchart':
        return 'Doğum Haritası';
      case 'personality':
        return 'Kişilik Analizi';
      case 'synastry':
        return 'Sinastri';
      default:
        return type;
    }
  }
}

class ProfileHistoryResponse {
  final List<ProfileReadingItem> items;

  ProfileHistoryResponse({required this.items});

  factory ProfileHistoryResponse.fromJson(Map<String, dynamic> json) {
    final list = json['items'];
    if (list is! List) return ProfileHistoryResponse(items: []);
    final items = list
        .map((e) => ProfileReadingItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return ProfileHistoryResponse(items: items);
  }
}
