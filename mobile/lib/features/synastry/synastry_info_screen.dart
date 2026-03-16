// lib/features/synastry/synastry_info_screen.dart
import 'package:flutter/material.dart';

import '../../models/synastry_models.dart';
import '../../services/device_id_service.dart';
import '../../services/synastry_api.dart';
import '../../services/profile_store.dart';
import '../../widgets/mystic_scaffold.dart';

import 'synastry_generating_screen.dart';

class SynastryInfoScreen extends StatefulWidget {
  const SynastryInfoScreen({super.key});

  @override
  State<SynastryInfoScreen> createState() => _SynastryInfoScreenState();
}

class _SynastryInfoScreenState extends State<SynastryInfoScreen> {
  final _api = SynastryApi();

  // Person A
  final _aName = TextEditingController();
  final _aDate = TextEditingController(); // YYYY-MM-DD
  final _aTime = TextEditingController(); // HH:MM
  final _aCity = TextEditingController();
  final _aCountry = TextEditingController(text: 'Türkiye');

  // Person B
  final _bName = TextEditingController();
  final _bDate = TextEditingController();
  final _bTime = TextEditingController();
  final _bCity = TextEditingController();
  final _bCountry = TextEditingController(text: 'Türkiye');

  final _question = TextEditingController();
  String _topic = 'Genel';

  bool _loading = false;

  // ✅ Profil → Kişi A otomatik doldurma
  bool _useProfileForA = true;
  bool _prefilledAOnce = false;

  // ✅ Profil değişimini yakalamak için signature
  String _lastProfileSigA = "";

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
    await ProfileStore.instance.init(alsoSyncServer: true);
    _applyProfileToAIfNeeded();
    ProfileStore.instance.addListener(_onProfileChanged);
  }

  void _onProfileChanged() {
    if (!mounted) return;
    _applyProfileToAIfNeeded();
  }

  void _applyProfileToAIfNeeded() {
    if (!_useProfileForA) return;

    final me = ProfileStore.instance.me;
    if (me == null) return;

    // ✅ profil değiştiyse yeniden prefill et (değişmediyse ve bir kez yaptıysak dokunma)
    final sig = "${me.displayName}|${me.birthDate}|${me.birthTime}|${me.birthPlace}";
    if (_prefilledAOnce && _lastProfileSigA == sig) return;
    _lastProfileSigA = sig;

    final name = me.displayName.trim();
    final bd = (me.birthDate ?? '').trim();
    final bt = (me.birthTime ?? '').trim();
    final city = (me.birthPlace ?? '').trim();

    // Kullanıcının yazdığını ezmeyelim: sadece boşsa doldur
    if (_aName.text.trim().isEmpty && name.isNotEmpty && name != 'Misafir') {
      _aName.text = name;
    }
    if (_aDate.text.trim().isEmpty && bd.isNotEmpty) {
      _aDate.text = bd;
    }
    if (_aTime.text.trim().isEmpty && bt.isNotEmpty) {
      _aTime.text = bt;
    }
    if (_aCity.text.trim().isEmpty && city.isNotEmpty) {
      _aCity.text = city;
    }
    if (_aCountry.text.trim().isEmpty) {
      _aCountry.text = 'Türkiye';
    }

    if (_aName.text.trim().isNotEmpty || _aDate.text.trim().isNotEmpty || _aCity.text.trim().isNotEmpty) {
      _prefilledAOnce = true;
      if (mounted) setState(() {});
    }
  }

  void _setUseProfileForA(bool v) {
    setState(() {
      _useProfileForA = v;
      if (_useProfileForA) {
        _prefilledAOnce = false;
        _lastProfileSigA = "";
        _applyProfileToAIfNeeded();
      } else {
        // Başkası için: A'yı temizle
        _aName.clear();
        _aDate.clear();
        _aTime.clear();
        _aCity.clear();
        _aCountry.text = 'Türkiye';
      }
    });
  }

  void _clearB() {
    setState(() {
      _bName.clear();
      _bDate.clear();
      _bTime.clear();
      _bCity.clear();
      _bCountry.text = 'Türkiye';
    });
  }

  Future<void> _start() async {
    if (_loading) return;

    if (_aName.text.trim().isEmpty ||
        _aDate.text.trim().isEmpty ||
        _aCity.text.trim().isEmpty ||
        _bName.text.trim().isEmpty ||
        _bDate.text.trim().isEmpty ||
        _bCity.text.trim().isEmpty) {
      _toast('İki kişi için isim + doğum tarihi + şehir zorunlu.');
      return;
    }

    setState(() => _loading = true);
    try {
      final deviceId = await DeviceIdService.getOrCreate();

      final req = SynastryStartRequest(
        nameA: _aName.text.trim(),
        birthDateA: _aDate.text.trim(),
        birthTimeA: _aTime.text.trim().isEmpty ? null : _aTime.text.trim(),
        birthCityA: _aCity.text.trim(),
        birthCountryA: _aCountry.text.trim().isEmpty ? 'Türkiye' : _aCountry.text.trim(),
        nameB: _bName.text.trim(),
        birthDateB: _bDate.text.trim(),
        birthTimeB: _bTime.text.trim().isEmpty ? null : _bTime.text.trim(),
        birthCityB: _bCity.text.trim(),
        birthCountryB: _bCountry.text.trim().isEmpty ? 'Türkiye' : _bCountry.text.trim(),
        topic: _topic,
        question: _question.text.trim().isEmpty ? null : _question.text.trim(),
      );

      final startRes = await _api.start(req, deviceId: deviceId);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SynastryGeneratingScreen(
            readingId: startRes.readingId,
            title: 'Sinastri (Aşk Uyumu)',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _toast('Hata: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    ProfileStore.instance.removeListener(_onProfileChanged);

    _aName.dispose();
    _aDate.dispose();
    _aTime.dispose();
    _aCity.dispose();
    _aCountry.dispose();
    _bName.dispose();
    _bDate.dispose();
    _bTime.dispose();
    _bCity.dispose();
    _bCountry.dispose();
    _question.dispose();
    super.dispose();
  }

  Widget _sectionTitle(String t) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          t,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    final now = DateTime.now();
    DateTime initial = now.subtract(const Duration(days: 365 * 25));
    try {
      final s = ctrl.text.trim();
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
    if (picked != null && mounted) {
      ctrl.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      setState(() {});
    }
  }

  Future<void> _pickTime(TextEditingController ctrl) async {
    TimeOfDay initial = const TimeOfDay(hour: 12, minute: 0);
    try {
      final s = ctrl.text.trim();
      if (s.length >= 4) {
        final parts = s.split(':');
        if (parts.length >= 2) {
          initial = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        }
      }
    } catch (_) {}
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null && mounted) {
      ctrl.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {});
    }
  }

  Widget _dateRow(TextEditingController ctrl, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _pickDate(ctrl),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1120).withOpacity(0.75),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today, color: Color(0xFFF5C361), size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(
                      ctrl.text.trim().isEmpty ? 'Tarih seçin' : ctrl.text,
                      style: TextStyle(color: ctrl.text.trim().isEmpty ? Colors.white38 : Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timeRow(TextEditingController ctrl, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _pickTime(ctrl),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1120).withOpacity(0.75),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              const Icon(Icons.access_time, color: Color(0xFFF5C361), size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(
                      ctrl.text.trim().isEmpty ? 'Saat seçin (opsiyonel)' : ctrl.text,
                      style: TextStyle(color: ctrl.text.trim().isEmpty ? Colors.white38 : Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: Colors.white70),
          hintStyle: const TextStyle(color: Colors.white38),
          filled: true,
          fillColor: const Color(0xFF0B1120).withOpacity(0.75),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.white12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD6B15E)),
          ),
        ),
      ),
    );
  }

  Widget _dropdown() {
    final items = ['Genel', 'Aşk', 'İletişim', 'Güven', 'Evlilik', 'Ayrılık', 'Barışma', 'Uzun Vade'];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1120).withOpacity(0.75),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _topic,
          isExpanded: true,
          dropdownColor: const Color(0xFF0B1120),
          iconEnabledColor: Colors.white70,
          style: const TextStyle(color: Colors.white),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => _topic = v ?? 'Genel'),
        ),
      ),
    );
  }

  Widget _profileToggleA() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              "Kişi A = Profilim",
              style: TextStyle(color: Colors.white.withOpacity(0.88), fontWeight: FontWeight.w900),
            ),
          ),
          Switch(
            value: _useProfileForA,
            onChanged: _setUseProfileForA,
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
                const Expanded(
                  child: Text(
                    'Sinastri – Bilgiler',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            Expanded(
              child: AbsorbPointer(
                absorbing: _loading,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: Column(
                    children: [
                      _profileToggleA(),

                      _sectionTitle('Kişi A'),
                      _field(_aName, 'Ad Soyad'),
                      _dateRow(_aDate, 'Doğum Tarihi'),
                      _timeRow(_aTime, 'Doğum Saati (opsiyonel)'),
                      _field(_aCity, 'Doğum Şehri', hint: 'İstanbul'),
                      _field(_aCountry, 'Ülke', hint: 'Türkiye'),

                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(child: _sectionTitle('Kişi B')),
                          TextButton(
                            onPressed: _clearB,
                            child: const Text(
                              "B'yi Temizle",
                              style: TextStyle(color: Color(0xFFF5C361), fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                      _field(_bName, 'Ad Soyad'),
                      _dateRow(_bDate, 'Doğum Tarihi'),
                      _timeRow(_bTime, 'Doğum Saati (opsiyonel)'),
                      _field(_bCity, 'Doğum Şehri', hint: 'İzmir'),
                      _field(_bCountry, 'Ülke', hint: 'Türkiye'),

                      const SizedBox(height: 14),
                      _sectionTitle('Odak'),
                      _dropdown(),
                      _field(_question, 'Soru (opsiyonel)', hint: 'Bu ilişkide en kritik dinamik ne?'),

                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD6B15E),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _start,
                          child: _loading
                              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Devam Et', style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
