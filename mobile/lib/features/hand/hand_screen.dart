// mobile/lib/features/hand/hand_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/hand_reading.dart';
import '../../services/device_id_service.dart';
import '../../services/hand_api.dart';
import '../../services/profile_store.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/mystic_scaffold.dart';
import 'hand_loading_screen.dart';

class HandScreen extends StatefulWidget {
  const HandScreen({super.key});

  @override
  State<HandScreen> createState() => _HandScreenState();
}

class _HandScreenState extends State<HandScreen> {
  final _formKey = GlobalKey<FormState>();
  final _topicController = TextEditingController(text: 'Genel');
  final _questionController = TextEditingController();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();

  // UI'da kalsın istiyorsan saklayabiliriz, ama şu an API'ye göndermiyoruz
  String? _dominantHand; // right/left
  String? _photoHand; // right/left

  final ImagePicker _picker = ImagePicker();
  final List<File> _photos = [];

  bool _loading = false;

  // ✅ Profil otomatik doldurma kontrolü
  bool _applyingProfile = false;
  bool _nameTouched = false;
  bool _ageTouched = false;

  // ✅ Backend ile uyumlu: settings.min_photos=3, max_photos=5
  static const int _minPhotos = 3;
  static const int _maxPhotos = 5;

  @override
  void initState() {
    super.initState();

    // Kullanıcı yazdı mı takibi
    _nameController.addListener(() {
      if (_applyingProfile) return;
      _nameTouched = true;
    });
    _ageController.addListener(() {
      if (_applyingProfile) return;
      _ageTouched = true;
    });

    // Profil -> form otomatik dolsun
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrapProfile();
    });
  }

  @override
  void dispose() {
    _topicController.dispose();
    _questionController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  int? _ageFromBirthDate(String? birthDate) {
    final s = (birthDate ?? '').trim();
    if (s.isEmpty) return null;
    // YYYY-MM-DD
    final parts = s.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;

    final now = DateTime.now();
    var age = now.year - y;
    final hadBirthdayThisYear = (now.month > m) || (now.month == m && now.day >= d);
    if (!hadBirthdayThisYear) age -= 1;

    if (age < 0 || age > 120) return null;
    return age;
  }

  Future<void> _bootstrapProfile() async {
    if (!mounted) return;

    // ✅ listener’ların “touched” yazmaması için setState ile bayrak
    setState(() => _applyingProfile = true);

    try {
      // 1) Local hızlı yükle (init içi)
      await ProfileStore.instance.init(alsoSyncServer: true);

      // 2) Eğer server’dan “Misafir” yerine gerçek veri geldiyse,
      // refresh sonrası tekrar apply etmek bazen iş görüyor.
      // (ProfileStore init içinde zaten silent refresh yapıyor ama
      // yine de güvenli olsun diye bir kez daha sync deneyebiliriz)
      await ProfileStore.instance.refreshFromServer(silent: true);

      final me = ProfileStore.instance.me;
      if (me == null) return;

      final profileName = me.displayName.trim();
      final canUseName = profileName.isNotEmpty && profileName != 'Misafir';

      final computedAge = _ageFromBirthDate(me.birthDate);

      // ✅ İsim: sadece boşsa ve kullanıcı dokunmadıysa doldur
      if (!_nameTouched && _nameController.text.trim().isEmpty && canUseName) {
        _nameController.text = profileName;
      }

      // ✅ Yaş: sadece boşsa ve kullanıcı dokunmadıysa doldur
      if (!_ageTouched && _ageController.text.trim().isEmpty && computedAge != null) {
        _ageController.text = computedAge.toString();
      }

      // (İstersen doğum yeri / doğum saati gibi alanlar el falında yok — okey)
      if (mounted) setState(() {});
    } catch (_) {
      // offline vs. sessiz geç
    } finally {
      if (mounted) setState(() => _applyingProfile = false);
    }
  }

  Future<void> _pickFromGalleryMulti() async {
    final picked = await _picker.pickMultiImage(imageQuality: 88);
    if (picked.isEmpty) return;

    setState(() {
      for (final x in picked) {
        if (_photos.length >= _maxPhotos) break;
        _photos.add(File(x.path));
      }
    });
  }

  Future<void> _pickFromCamera() async {
    if (_photos.length >= _maxPhotos) return;
    final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 88);
    if (picked == null) return;

    setState(() => _photos.add(File(picked.path)));
  }

  void _removePhoto(int index) => setState(() => _photos.removeAt(index));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_photos.length < _minPhotos || _photos.length > _maxPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lütfen $_minPhotos ile $_maxPhotos arası el fotoğrafı ekle.')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final deviceId = await DeviceIdService.getOrCreate();

      final HandReading reading = await HandApi.start(
        deviceId: deviceId,
        name: _nameController.text.trim(),
        age: int.tryParse(_ageController.text.trim()),
        topic: _topicController.text.trim(),
        question: _questionController.text.trim(),
      );

      await HandApi.uploadImages(
        deviceId: deviceId,
        readingId: reading.id,
        imageFiles: _photos,
      );

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => HandLoadingScreen(readingId: reading.id)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _photoArea() {
    if (_photos.isEmpty) {
      return GlassCard(
        child: Column(
          children: const [
            Icon(Icons.pan_tool_alt_outlined, size: 44, color: Colors.white),
            SizedBox(height: 10),
            Text(
              '3-5 foto ekle:\n(avuç içi net, ışık iyi, çizgiler görünür)',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return GlassCard(
      padding: const EdgeInsets.all(10),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _photos.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemBuilder: (context, i) {
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _photos[i],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
              Positioned(
                right: 4,
                top: 4,
                child: InkWell(
                  onTap: () => _removePhoto(i),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _handPickers() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('El Bilgisi (opsiyonel)', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _dominantHand,
                  decoration: const InputDecoration(labelText: 'Baskın el (opsiyonel)'),
                  items: const [
                    DropdownMenuItem(value: 'right', child: Text('Sağ el')),
                    DropdownMenuItem(value: 'left', child: Text('Sol el')),
                  ],
                  onChanged: (v) => setState(() => _dominantHand = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _photoHand,
                  decoration: const InputDecoration(labelText: 'Fotoğraftaki el (opsiyonel)'),
                  items: const [
                    DropdownMenuItem(value: 'right', child: Text('Sağ el')),
                    DropdownMenuItem(value: 'left', child: Text('Sol el')),
                  ],
                  onChanged: (v) => setState(() => _photoHand = v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MysticScaffold(
      scrimOpacity: 0.82,
      patternOpacity: 0.18,
      appBar: AppBar(title: const Text('El Falı')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _photoArea(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _pickFromCamera,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Kamera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _pickFromGalleryMulti,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Galeri (çoklu)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Seçilen foto: ${_photos.length}/$_maxPhotos (min $_minPhotos)',
              style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12),
            ),
            const SizedBox(height: 18),
            _handPickers(),
            const SizedBox(height: 18),
            GlassCard(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _topicController,
                      decoration: const InputDecoration(labelText: 'Konu (Aşk/İş/Para/Genel)'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Zorunlu' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _questionController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Sorun / odak noktan'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Zorunlu' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'İsim'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Zorunlu' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Yaş (opsiyonel)'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            GradientButton(
              text: _loading ? 'Yükleniyor...' : 'Devam Et',
              onPressed: _loading ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
