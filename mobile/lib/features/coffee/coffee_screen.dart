import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/coffee_reading.dart';
import '../../services/coffee_api.dart';
import '../../services/device_id_service.dart';
import '../../services/profile_store.dart';

import '../../widgets/glass_card.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/mystic_scaffold.dart';
import 'coffee_loading_screen.dart';

class CoffeeScreen extends StatefulWidget {
  const CoffeeScreen({super.key});

  @override
  State<CoffeeScreen> createState() => _CoffeeScreenState();
}

class _CoffeeScreenState extends State<CoffeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _topicController = TextEditingController(text: 'Genel');
  final _questionController = TextEditingController();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final List<XFile> _photos = [];

  bool _loading = false;

  bool _nameDirty = false;
  bool _nameAppliedOnce = false;

  bool _ageDirty = false;
  bool _ageAppliedOnce = false;

  @override
  void initState() {
    super.initState();

    _nameController.addListener(() => _nameDirty = true);
    _ageController.addListener(() => _ageDirty = true);

    _bootProfileForCoffee();
  }

  Future<void> _bootProfileForCoffee() async {
    try {
      await ProfileStore.instance.init(alsoSyncServer: true);
      ProfileStore.instance.addListener(_onProfileChanged);
      _applyFromProfile(force: true);
    } catch (_) {
      // offline vs sessiz geç
    }
  }

  void _onProfileChanged() {
    if (!mounted) return;
    _applyFromProfile(force: false);
  }

  int? _ageFromBirthDate(String? birthDate) {
    final s = (birthDate ?? '').trim();
    if (s.isEmpty) return null;

    final parts = s.split('-');
    if (parts.length != 3) return null;

    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;

    final now = DateTime.now();
    int age = now.year - y;

    final birthdayThisYear = DateTime(now.year, m, d);
    if (now.isBefore(birthdayThisYear)) {
      age -= 1;
    }

    if (age < 0 || age > 120) return null;
    return age;
  }

  void _applyFromProfile({required bool force}) {
    final me = ProfileStore.instance.me;
    if (me == null) return;

    if (force || (!_nameDirty && !_nameAppliedOnce)) {
      final name = me.displayName.trim();
      if (name.isNotEmpty && name != 'Misafir') {
        if (_nameController.text.trim().isEmpty || force) {
          _nameController.text = name;
        }
      }
      _nameAppliedOnce = true;
      _nameDirty = false;
    }

    if (force || (!_ageDirty && !_ageAppliedOnce)) {
      final computedAge = _ageFromBirthDate(me.birthDate);
      if (computedAge != null) {
        if (_ageController.text.trim().isEmpty || force) {
          _ageController.text = computedAge.toString();
        }
      }
      _ageAppliedOnce = true;
      _ageDirty = false;
    }

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ProfileStore.instance.removeListener(_onProfileChanged);

    _topicController.dispose();
    _questionController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _pickFromGalleryMulti() async {
    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;

    setState(() {
      for (final x in picked) {
        if (_photos.length >= 5) break;
        _photos.add(x);
      }
    });
  }

  Future<void> _pickFromCamera() async {
    if (_photos.length >= 5) return;
    final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (picked == null) return;
    setState(() => _photos.add(picked));
  }

  void _removePhoto(int index) => setState(() => _photos.removeAt(index));

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  String _friendlyMessageFromApiError(ApiException e) {
    // Öncelik: backend detail gerçekten kullanıcı mesajıysa göster
    final detail = e.message.trim();

    if (e.statusCode == 400) {
      // Foto doğrulama gibi şeylerde backend'in mesajı en iyi mesajdır
      return detail.isNotEmpty ? detail : 'Geçersiz istek.';
    }

    if (e.statusCode == 402) {
      return 'Ödeme gerekli. Lütfen ödemeyi tamamla.';
    }

    if (e.statusCode == 403) {
      return 'Bu işlem için yetki yok.';
    }

    if (e.statusCode == 404) {
      return 'Kayıt bulunamadı. Lütfen tekrar dene.';
    }

    if (e.statusCode == 503) {
      // Senin log’daki senaryo: quota bitti / AI geçici unavailable
      // Backend detail: "OpenAI quota/billing yetersiz." gibi gelecek
      if (detail.toLowerCase().contains('quota') ||
          detail.toLowerCase().contains('billing') ||
          detail.toLowerCase().contains('kota')) {
        return 'AI kotası şu an dolu. Biraz sonra tekrar dene.';
      }
      return 'AI şu an kullanılamıyor. Biraz sonra tekrar dene.';
    }

    if (e.statusCode >= 500) {
      return 'Sunucuda geçici bir sorun var. Biraz sonra tekrar dene.';
    }

    // fallback
    return detail.isNotEmpty ? detail : 'Bir hata oluştu. Lütfen tekrar dene.';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_photos.length < 3 || _photos.length > 5) {
      _showSnack('Lütfen 3 ile 5 fotoğraf ekle.');
      return;
    }

    setState(() => _loading = true);

    try {
      final deviceId = await DeviceIdService.getOrCreate();

      final CoffeeReading reading = await CoffeeApi.start(
        name: _nameController.text.trim(),
        age: int.tryParse(_ageController.text.trim()),
        topic: _topicController.text.trim(),
        question: _questionController.text.trim(),
        deviceId: deviceId,
      );

      await CoffeeApi.uploadPhotos(
        readingId: reading.id,
        imageFiles: _photos,
        deviceId: deviceId,
      );

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CoffeeLoadingScreen(readingId: reading.id)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(_friendlyMessageFromApiError(e));
    } catch (_) {
      if (!mounted) return;
      _showSnack('Beklenmeyen bir hata oluştu. Lütfen tekrar dene.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _photoArea() {
    if (_photos.isEmpty) {
      return GlassCard(
        child: Column(
          children: const [
            Icon(Icons.coffee_outlined, size: 44, color: Colors.white),
            SizedBox(height: 10),
            Text(
              '3-5 foto ekle:\n(1) fincan içi, (2) tabak, (3) üstten',
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
                child: kIsWeb
                    ? Image.network(
                        _photos[i].path,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      )
                    : Image.file(
                        File(_photos[i].path),
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

  @override
  Widget build(BuildContext context) {
    return MysticScaffold(
      scrimOpacity: 0.82,
      patternOpacity: 0.18,
      appBar: AppBar(title: const Text('Kahve Falı')),
      body: SafeArea(
        child: Padding(
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
      ),
    );
  }
}
