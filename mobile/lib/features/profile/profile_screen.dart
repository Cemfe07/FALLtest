import 'dart:async';
import 'package:flutter/material.dart';

import '../../models/profile_models.dart';
import '../../services/device_id_service.dart';
import '../../services/profile_api.dart';
import '../../services/profile_store.dart';
import '../../widgets/mystic_scaffold.dart';
import '../coffee/coffee_result_screen.dart';
import '../hand/hand_result_screen.dart';
import '../numerology/numerology_result_screen.dart';
import '../personality/personality_result_screen.dart';
import '../synastry/synastry_result_screen.dart';
import 'profile_legal_screen.dart';
import 'reading_detail_loader_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _birthDateCtrl = TextEditingController(); // YYYY-MM-DD
  final _birthPlaceCtrl = TextEditingController();
  final _birthTimeCtrl = TextEditingController(); // HH:MM

  bool _loading = true;
  bool _saving = false;

  /// Kullanıcı alanlara dokunduysa true.
  /// Store refresh geldi diye kullanıcı girdisini ezmeyelim.
  bool _dirty = false;

  /// İlk kez store’dan form doldurma (ya da dirty değilken)
  bool _appliedOnce = false;

  /// Benim Okumalarım: son 5 okuma
  List<ProfileReadingItem>? _readings;
  bool _readingsLoading = false;
  String? _readingsError;
  /// Önceki yüklemede yorumu bekleyen okuma id'leri (yorum hazır olunca bildirim için)
  Set<String> _pendingReadingIds = {};
  Timer? _pendingRefreshTimer;

  @override
  void initState() {
    super.initState();
    _boot();

    _nameCtrl.addListener(_markDirty);
    _birthDateCtrl.addListener(_markDirty);
    _birthPlaceCtrl.addListener(_markDirty);
    _birthTimeCtrl.addListener(_markDirty);
  }

  void _markDirty() {
    // typing sırasında sürekli setState yapmayalım
    _dirty = true;
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 90),
      ),
    );
  }

  Future<void> _boot() async {
    try {
      // ✅ local hızlı yükle + server sync
      await ProfileStore.instance.init(alsoSyncServer: true);

      // store değişince UI kendini yenilesin
      ProfileStore.instance.addListener(_onStoreChanged);

      // ilk dolum
      _applyFromStore(force: true);

      // Son 5 okumayı yükle
      _loadReadings();
    } catch (_) {
      // offline vs. sessiz geç
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadReadings() async {
    if (!mounted) return;
    setState(() {
      _readingsLoading = true;
      _readingsError = null;
    });
    try {
      final deviceId = await DeviceIdService.getOrCreate();
      final res = await ProfileApi.getHistory(deviceId: deviceId, limit: 20);
      if (!mounted) return;
      final newItems = res.items;
      final nowPending = <String>{};
      bool anyJustReady = false;
      for (final r in newItems) {
        final hasResult = (r.resultText ?? '').trim().isNotEmpty;
        if (r.isPaid && !hasResult) {
          nowPending.add(r.id);
        } else if (r.isPaid && hasResult && _pendingReadingIds.contains(r.id)) {
          anyJustReady = true;
        }
      }
      setState(() {
        _readings = newItems;
        _readingsLoading = false;
        _readingsError = null;
        _pendingReadingIds = nowPending;
      });
      _startOrStopPendingRefresh();
      if (anyJustReady) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yorumunuz hazır! Listeden açabilirsiniz.'),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.fromLTRB(18, 0, 18, 90),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _readings = null;
          _readingsLoading = false;
          _readingsError = e.toString();
        });
      }
    }
  }

  void _onStoreChanged() {
    if (!mounted) return;
    _applyFromStore(force: false);
  }

  void _startOrStopPendingRefresh() {
    _pendingRefreshTimer?.cancel();
    _pendingRefreshTimer = null;
    if (_pendingReadingIds.isEmpty || !mounted) return;
    _pendingRefreshTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (!mounted || _pendingReadingIds.isEmpty) {
        _pendingRefreshTimer?.cancel();
        _pendingRefreshTimer = null;
        return;
      }
      _loadReadings();
    });
  }

  void _openReading(ProfileReadingItem r) {
    if (r.id.trim().isEmpty) return;
    // Profilde result_text varsa direkt sonuç ekranına git (detail API boş dönse bile açılsın)
    final text = (r.resultText ?? '').trim();
    if (text.isNotEmpty) {
      if (r.type == 'coffee') {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CoffeeResultScreen(resultText: text)),
        );
        return;
      }
      if (r.type == 'numerology') {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NumerologyResultScreen(
              title: r.title.isNotEmpty ? r.title : r.typeLabel,
              resultText: text,
            ),
          ),
        );
        return;
      }
      if (r.type == 'synastry') {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SynastryResultScreen(readingId: r.id, resultText: text),
          ),
        );
        return;
      }
    }
    if (r.type == 'hand') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => HandResultScreen(readingId: r.id)),
      );
      return;
    }
    if (r.type == 'personality') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PersonalityResultScreen(readingId: r.id)),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReadingDetailLoaderScreen(
          readingId: r.id,
          type: r.type,
          prefetchedResultText: text.isNotEmpty ? text : null,
        ),
      ),
    );
  }

  void _applyFromStore({required bool force}) {
    final me = ProfileStore.instance.me;
    if (me == null) return;

    // Eğer kullanıcı yazmaya başladıysa ve force değilse ezme
    if (!force && _dirty) return;

    // İlk kez uygula veya force
    if (_appliedOnce && !force) return;

    final name = me.displayName.trim();
    final bd = (me.birthDate ?? '').trim();
    final bp = (me.birthPlace ?? '').trim();
    final bt = (me.birthTime ?? '').trim();

    _nameCtrl.text = (name.isNotEmpty && name != 'Misafir') ? name : '';
    _birthDateCtrl.text = bd;
    _birthPlaceCtrl.text = bp;
    _birthTimeCtrl.text = bt;

    _appliedOnce = true;

    // store’dan bastık → kullanıcı değişikliği sayma
    _dirty = false;

    setState(() {});
  }

  Future<void> _saveAll() async {
    if (_saving) return;

    final name = _nameCtrl.text.trim();
    final birthDate = _birthDateCtrl.text.trim();
    final birthPlace = _birthPlaceCtrl.text.trim();
    final birthTime = _birthTimeCtrl.text.trim();

    if (name.isEmpty) {
      _toast("İsim boş olamaz (takma ad da olur).");
      return;
    }

    setState(() => _saving = true);
    try {
      await ProfileStore.instance.save(
        ProfileUpsertRequest(
          displayName: name,
          birthDate: birthDate.isEmpty ? null : birthDate,
          birthPlace: birthPlace.isEmpty ? null : birthPlace,
          birthTime: birthTime.isEmpty ? null : birthTime,
        ),
      );

      // Kaydedildi → artık dirty değil
      _dirty = false;

      _toast("Kaydedildi ✅");
    } catch (e) {
      _toast("Kaydetme hatası: $e");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _pendingRefreshTimer?.cancel();
    ProfileStore.instance.removeListener(_onStoreChanged);

    _nameCtrl.removeListener(_markDirty);
    _birthDateCtrl.removeListener(_markDirty);
    _birthPlaceCtrl.removeListener(_markDirty);
    _birthTimeCtrl.removeListener(_markDirty);

    _nameCtrl.dispose();
    _birthDateCtrl.dispose();
    _birthPlaceCtrl.dispose();
    _birthTimeCtrl.dispose();
    super.dispose();
  }

  static IconData _iconForType(String type) {
    switch (type) {
      case 'coffee':
        return Icons.coffee;
      case 'hand':
        return Icons.back_hand_outlined;
      case 'tarot':
        return Icons.style;
      case 'numerology':
        return Icons.numbers;
      case 'birthchart':
        return Icons.public;
      case 'personality':
        return Icons.person;
      case 'synastry':
        return Icons.favorite;
      default:
        return Icons.auto_stories;
    }
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _aboutBullet(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFFF5C361)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12, height: 1.3),
          ),
        ),
      ],
    );
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        border: InputBorder.none,
      );

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    DateTime initial = now.subtract(const Duration(days: 365 * 25));
    try {
      final s = _birthDateCtrl.text.trim();
      if (s.length >= 10) {
        final parts = s.split('-');
        if (parts.length == 3) {
          initial = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        }
      }
    } catch (_) {}
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900, 1, 1),
      lastDate: DateTime(now.year, 12, 31),
    );
    if (picked != null) {
      _birthDateCtrl.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      _markDirty();
      setState(() {});
    }
  }

  Future<void> _pickBirthTime() async {
    TimeOfDay initial = const TimeOfDay(hour: 12, minute: 0);
    try {
      final s = _birthTimeCtrl.text.trim();
      if (s.length >= 4) {
        final parts = s.split(':');
        if (parts.length >= 2) {
          initial = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        }
      }
    } catch (_) {}
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      _birthTimeCtrl.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      _markDirty();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return MysticScaffold(
      scrimOpacity: 0.70,
      patternOpacity: 0.22,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                const Text(
                  "Profil",
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadReadings,
                      color: const Color(0xFFF5C361),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                        children: [
                        _card(
                          title: "Hakkında LunAura",
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "LunAura, tek uygulamada birden fazla kişisel analiz deneyimi sunar; astroloji ve fal kategorisinde benzersiz bir birleşik platformdur.",
                                style: TextStyle(color: Colors.white.withOpacity(0.90), fontSize: 13, height: 1.35),
                              ),
                              const SizedBox(height: 12),
                              _aboutBullet(Icons.integration_instructions_outlined, "7+ analiz türü: Kahve falı, el falı, tarot, numeroloji, doğum haritası, kişilik analizi ve sinastri tek uygulamada."),
                              const SizedBox(height: 8),
                              _aboutBullet(Icons.auto_awesome, "AI ile kişiselleştirilmiş yorumlar: Her okuma, sorunuza ve bilgilerinize özel üretilir."),
                              const SizedBox(height: 8),
                              _aboutBullet(Icons.picture_as_pdf_outlined, "PDF rapor indirme: Kişilik ve sinastri raporlarını cihazınıza kaydedebilirsiniz."),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _card(
                          title: "Kişisel Bilgiler",
                          child: Column(
                            children: [
                              TextField(
                                controller: _nameCtrl,
                                style: const TextStyle(color: Colors.white),
                                decoration: _dec("Ad / Takma ad"),
                              ),
                              const Divider(color: Colors.white12),
                              InkWell(
                                onTap: _pickBirthDate,
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today, color: Color(0xFFF5C361), size: 22),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _birthDateCtrl.text.trim().isEmpty ? 'Doğum tarihi seçin' : _birthDateCtrl.text,
                                          style: TextStyle(color: _birthDateCtrl.text.trim().isEmpty ? Colors.white54 : Colors.white, fontSize: 16),
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right, color: Colors.white54),
                                    ],
                                  ),
                                ),
                              ),
                              const Divider(color: Colors.white12),
                              TextField(
                                controller: _birthPlaceCtrl,
                                style: const TextStyle(color: Colors.white),
                                decoration: _dec("Doğum yeri (opsiyonel)"),
                              ),
                              const Divider(color: Colors.white12),
                              InkWell(
                                onTap: _pickBirthTime,
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.access_time, color: Color(0xFFF5C361), size: 22),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _birthTimeCtrl.text.trim().isEmpty ? 'Doğum saati seçin (opsiyonel)' : _birthTimeCtrl.text,
                                          style: TextStyle(color: _birthTimeCtrl.text.trim().isEmpty ? Colors.white54 : Colors.white, fontSize: 16),
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right, color: Colors.white54),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFF5C361),
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  onPressed: _saving ? null : _saveAll,
                                  child: _saving
                                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Text("Kaydet", style: TextStyle(fontWeight: FontWeight.w900)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _card(
                          title: "Benim Okumalarım",
                          child: _readingsLoading
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(child: SizedBox(height: 28, width: 28, child: CircularProgressIndicator(strokeWidth: 2))),
                                )
                              : _readingsError != null
                                  ? Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Text(_readingsError!, style: TextStyle(color: Colors.orange.shade200, fontSize: 12)),
                                    )
                                  : _readings == null || _readings!.isEmpty
                                      ? Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          child: Text(
                                            "Henüz okuma yok. Fal türlerinden birini deneyerek ilk okumanı oluşturabilirsin.",
                                            style: TextStyle(color: Colors.white.withOpacity(0.80), fontSize: 13, height: 1.3),
                                          ),
                                        )
                                      : Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: _readings!.take(20).map((r) {
                                            final dateStr = r.createdAt != null
                                                ? "${r.createdAt!.day}.${r.createdAt!.month}.${r.createdAt!.year}"
                                                : null;
                                            const previewLen = 120;
                                            final hasResult = r.resultText != null && r.resultText!.isNotEmpty;
                                            final preview = hasResult
                                                ? (r.resultText!.length <= previewLen
                                                    ? r.resultText!
                                                    : '${r.resultText!.substring(0, previewLen)}...')
                                                : null;
                                            final waitingComment = r.isPaid && !hasResult;
                                            return Padding(
                                              padding: const EdgeInsets.only(bottom: 10),
                                              child: InkWell(
                                                onTap: () => _openReading(r),
                                                borderRadius: BorderRadius.circular(12),
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                                  child: Row(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Icon(_iconForType(r.type), color: const Color(0xFFF5C361), size: 20),
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(r.title.isNotEmpty ? r.title : r.typeLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                                                            if (dateStr != null)
                                                              Text(dateStr, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                                                            if (waitingComment) ...[
                                                              const SizedBox(height: 6),
                                                              Row(
                                                                children: [
                                                                  SizedBox(
                                                                    width: 14,
                                                                    height: 14,
                                                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber.shade200),
                                                                  ),
                                                                  const SizedBox(width: 8),
                                                                  Expanded(
                                                                    child: Text(
                                                                      'Yorumunuz hazırlanıyor... Ödeme alındı, kısa süre içinde buradan ulaşabilirsiniz.',
                                                                      style: TextStyle(color: Colors.amber.shade200, fontSize: 12, height: 1.35, fontStyle: FontStyle.italic),
                                                                      maxLines: 2,
                                                                      overflow: TextOverflow.ellipsis,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ] else if (preview != null) ...[
                                                              const SizedBox(height: 6),
                                                              Text(preview, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12, height: 1.35), maxLines: 3, overflow: TextOverflow.ellipsis),
                                                            ],
                                                          ],
                                                        ),
                                                      ),
                                                      const Icon(Icons.chevron_right, color: Colors.white54, size: 22),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                        ),
                        const SizedBox(height: 12),
                        _card(
                          title: "Yasal",
                          child: Column(
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text("Gizlilik Politikası", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                                trailing: const Icon(Icons.chevron_right, color: Colors.white70),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const ProfileLegalScreen(type: LegalType.privacy)),
                                ),
                              ),
                              const Divider(color: Colors.white12),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text("Kullanıcı Sözleşmesi", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                                trailing: const Icon(Icons.chevron_right, color: Colors.white70),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const ProfileLegalScreen(type: LegalType.terms)),
                                ),
                              ),
                              const Divider(color: Colors.white12),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text("Uyarı / Sorumluluk Reddi", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                                trailing: const Icon(Icons.chevron_right, color: Colors.white70),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const ProfileLegalScreen(type: LegalType.disclaimer)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
