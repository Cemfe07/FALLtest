import 'package:flutter/material.dart';

import '../../services/device_id_service.dart';
import '../../services/numerology_api.dart';
import '../../models/numerology_reading.dart';
import '../../widgets/mystic_scaffold.dart';
import '../../services/profile_store.dart';

import 'numerology_loading_screen.dart';

class NumerologyFormScreen extends StatefulWidget {
  const NumerologyFormScreen({super.key});

  @override
  State<NumerologyFormScreen> createState() => _NumerologyFormScreenState();
}

class _NumerologyFormScreenState extends State<NumerologyFormScreen> {
  final _nameCtrl = TextEditingController();
  final _birthDateCtrl = TextEditingController(); // YYYY-MM-DD
  final _topicCtrl = TextEditingController(text: "genel");
  final _questionCtrl = TextEditingController();

  bool _loading = false;

  // ✅ Profil ile otomatik doldurma kontrolü
  bool _useProfile = true;
  bool _prefilledOnce = false;

  // ✅ Profil değişince güncellemek için snapshot
  String _lastProfileSig = "";

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 90),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    // store init (local + server sync)
    await ProfileStore.instance.init(alsoSyncServer: true);

    // ilk açılışta profil doluysa alanlara bas
    _applyProfileIfNeeded();

    // store değişince tekrar dene (ama kullanıcı yazdığını ezme kuralı korunur)
    ProfileStore.instance.addListener(_onProfileChanged);
  }

  void _onProfileChanged() {
    if (!mounted) return;
    _applyProfileIfNeeded();
  }

  void _applyProfileIfNeeded() {
    if (!_useProfile) return;

    final me = ProfileStore.instance.me;
    if (me == null) return;

    // ✅ profil değiştiyse tekrar prefill et (değişmediyse ve bir kez yaptıysak dokunma)
    final sig = "${me.displayName}|${me.birthDate}|${me.birthTime}|${me.birthPlace}";
    if (_prefilledOnce && _lastProfileSig == sig) return;
    _lastProfileSig = sig;

    final name = me.displayName.trim();
    final bd = (me.birthDate ?? '').trim();

    // sadece boşsa doldur (kullanıcının yazdığını ezmeyelim)
    if (_nameCtrl.text.trim().isEmpty && name.isNotEmpty && name != 'Misafir') {
      _nameCtrl.text = name;
    }
    if (_birthDateCtrl.text.trim().isEmpty && bd.isNotEmpty) {
      _birthDateCtrl.text = bd;
    }

    // prefill yapıldı sayalım
    if (_nameCtrl.text.trim().isNotEmpty || _birthDateCtrl.text.trim().isNotEmpty) {
      _prefilledOnce = true;
      if (mounted) setState(() {});
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    DateTime? initial;
    try {
      final parts = _birthDateCtrl.text.trim().split("-");
      if (parts.length == 3) {
        initial = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      }
    } catch (_) {}

    initial ??= DateTime(now.year - 25, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900, 1, 1),
      lastDate: DateTime(now.year, 12, 31),
    );

    if (picked != null) {
      final y = picked.year.toString().padLeft(4, "0");
      final m = picked.month.toString().padLeft(2, "0");
      final d = picked.day.toString().padLeft(2, "0");
      _birthDateCtrl.text = "$y-$m-$d";
      setState(() {});
    }
  }

  void _setUseProfile(bool v) {
    setState(() {
      _useProfile = v;
      if (_useProfile) {
        // yeniden prefille izin ver
        _prefilledOnce = false;
        _lastProfileSig = "";
        _applyProfileIfNeeded();
      } else {
        // başkası için hızlı temizle
        _nameCtrl.clear();
        _birthDateCtrl.clear();
      }
    });
  }

  Future<void> _continueToPayment() async {
    final name = _nameCtrl.text.trim();
    final birthDate = _birthDateCtrl.text.trim();
    final topic = _topicCtrl.text.trim().isEmpty ? "genel" : _topicCtrl.text.trim();
    final question = _questionCtrl.text.trim();

    if (name.isEmpty) return _toast("Ad Soyad gir");
    if (birthDate.isEmpty) return _toast("Doğum tarihi seç/gir (YYYY-AA-GG)");
    if (_loading) return;

    setState(() => _loading = true);

    try {
      final deviceId = await DeviceIdService.getOrCreate();

      final NumerologyReading reading = await NumerologyApi.start(
        name: name,
        birthDate: birthDate,
        topic: topic,
        question: question.isEmpty ? null : question,
        deviceId: deviceId,
      );

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NumerologyLoadingScreen(
            readingId: reading.id,
            title: question.isNotEmpty ? question : 'Nümeroloji Analizi',
            name: name,
            birthDate: birthDate,
            question: question,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _toast("Hata: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    ProfileStore.instance.removeListener(_onProfileChanged);

    _nameCtrl.dispose();
    _birthDateCtrl.dispose();
    _topicCtrl.dispose();
    _questionCtrl.dispose();
    super.dispose();
  }

  Widget _field({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: child,
    );
  }

  Widget _profileToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.30),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              "Profil bilgilerimi kullan",
              style: TextStyle(color: Colors.white.withOpacity(0.88), fontWeight: FontWeight.w800),
            ),
          ),
          Switch(
            value: _useProfile,
            onChanged: _setUseProfile,
            activeColor: const Color(0xFFF5C361),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MysticScaffold(
      scrimOpacity: 0.62,
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
                  "Nümeroloji – Bilgiler",
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _profileToggle(),
                    const SizedBox(height: 12),

                    const Text(
                      "Gerekli Bilgiler",
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 12),

                    _field(
                      child: TextField(
                        controller: _nameCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: "Ad Soyad",
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    _field(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _birthDateCtrl.text.trim().isEmpty
                                  ? "Doğum Tarihi: Seçilmedi"
                                  : "Doğum Tarihi: ${_birthDateCtrl.text.trim()}",
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          IconButton(
                            onPressed: _pickBirthDate,
                            icon: const Icon(Icons.calendar_month, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    _field(
                      child: TextField(
                        controller: _topicCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: "Konu (genel/aşk/kariyer/para vb.)",
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    _field(
                      child: TextField(
                        controller: _questionCtrl,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: "Sorun (opsiyonel)",
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF5C361),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _loading ? null : _continueToPayment,
                  child: _loading
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text("Devam → Ödeme", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
