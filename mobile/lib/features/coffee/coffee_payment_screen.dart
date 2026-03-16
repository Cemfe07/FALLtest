import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/device_id_service.dart';
import '../../services/iap_service.dart';
import '../../services/product_catalog.dart';
import '../../services/coffee_api.dart';

import '../../models/coffee_reading.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/mystic_scaffold.dart';
import 'coffee_result_screen.dart';

class CoffeePaymentScreen extends StatefulWidget {
  final String readingId;
  const CoffeePaymentScreen({super.key, required this.readingId});

  @override
  State<CoffeePaymentScreen> createState() => _CoffeePaymentScreenState();
}

class _CoffeePaymentScreenState extends State<CoffeePaymentScreen> {
  bool _loading = false;
  String? _lastPaymentId;
  CoffeeReading? _reading;
  bool _loadingReading = true;
  String? _loadError;

  static const bool debugUseStoreIap = true;

  @override
  void initState() {
    super.initState();
    _loadReading();
  }

  bool _isReadyLockedOrDone(CoffeeReading? r) {
    if (r == null) return false;
    if (r.hasResult) return true;
    final s = r.status.toLowerCase().trim();
    return s == 'completed' || s == 'done' || s == 'ready_locked' || s == 'ready_unlocked';
  }

  Future<void> _loadReading() async {
    setState(() {
      _loadingReading = true;
      _loadError = null;
    });
    try {
      final deviceId = await DeviceIdService.getOrCreate();
      final r = await CoffeeApi.detail(readingId: widget.readingId, deviceId: deviceId);
      if (!mounted) return;
      setState(() {
        _reading = r;
        _loadingReading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loadingReading = false;
      });
    }
  }

  void _fireGenerate() {
    DeviceIdService.getOrCreate().then((deviceId) async {
      try {
        await CoffeeApi.generate(readingId: widget.readingId, deviceId: deviceId);
      } catch (_) {}
    });
  }

  bool _hasAnyPhotoFromDetail(Map<String, dynamic> d) {
    // Backend farklı isimlerle döndürebilir diye robust kontrol
    final candidates = [
      d['photos'],
      d['images'],
      d['image_urls'],
      d['photo_urls'],
      d['files'],
      d['uploaded_files'],
    ];

    for (final v in candidates) {
      if (v is List && v.isNotEmpty) return true;
      if (v is String && v.trim().isNotEmpty) return true;
    }
    return false;
  }

  Future<void> _pay() async {
    if (_loading) return;
    if (!_isReadyLockedOrDone(_reading)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yorum henüz hazır değil. Hazır olduğunda bu ekrandan kilidi açabilirsin.')),
      );
      return;
    }

    setState(() {
      _loading = true;
    });
    try {
      final deviceId = await DeviceIdService.getOrCreate();

      // ✅ 0) KRİTİK GARANTİ:
      // /payments/verify kahvede "photos must be uploaded" istiyor.
      // Boşuna store’a sokmamak için ödeme öncesi kontrol.
      final detail = await CoffeeApi.detailRaw(readingId: widget.readingId, deviceId: deviceId);
      final hasPhoto = _hasAnyPhotoFromDetail(detail);
      if (!hasPhoto) {
        throw Exception("Ödemeden önce fincan fotoğrafını yüklemelisin.");
      }

      final shouldUseIap = kReleaseMode || debugUseStoreIap;
      if (shouldUseIap) {
        final verify = await IapService.instance.buyAndVerify(
          readingId: widget.readingId,
          sku: ProductCatalog.coffee49,
        );

        if (!verify.verified) {
          throw Exception("Ödeme doğrulanamadı: ${verify.status}");
        }

        if (mounted) setState(() => _lastPaymentId = verify.paymentId);
      }

      _fireGenerate();
      if (!mounted) return;

      CoffeeReading? finalReading;
      for (var i = 0; i < 8; i++) {
        try {
          final r = await CoffeeApi.detail(readingId: widget.readingId, deviceId: deviceId);
          final t = (r.comment ?? '').trim();
          if (t.isNotEmpty) {
            finalReading = r;
            break;
          }
        } catch (_) {}
        await Future.delayed(const Duration(seconds: 2));
      }

      final finalText = (finalReading?.comment ?? '').trim();
      if (finalText.isEmpty) {
        throw Exception("Yorum henüz açılmadı. Lütfen Profil > Benim Okumalarım'dan tekrar deneyin.");
      }

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => CoffeeResultScreen(resultText: finalText)),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ödeme/Yorum hatası: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MysticScaffold(
      appBar: AppBar(title: const Text('Ödeme')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Kahve Falı', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  const Text('Yorumun hazır olduğunda bu ekrandan kilidi açabilirsin.'),
                  const SizedBox(height: 10),
                  if (_loadingReading)
                    Row(
                      children: [
                        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        const SizedBox(width: 8),
                        Text(
                          'Yorum durumu kontrol ediliyor...',
                          style: TextStyle(color: Colors.white.withOpacity(0.80), fontSize: 12),
                        ),
                      ],
                    )
                  else if (_loadError != null)
                    Text(
                      'Yorum durumu alınamadı. Profil > Benim Okumalarım’dan kontrol et.',
                      style: TextStyle(color: Colors.orange.shade200, fontSize: 12),
                    )
                  else if (!_isReadyLockedOrDone(_reading))
                    Text(
                      'Yorum henüz hazırlanıyor. Hazır olduğunda bildirim alırsın.',
                      style: TextStyle(color: Colors.white.withOpacity(0.80), fontSize: 12),
                    )
                  else
                    Text(
                      'Yorumun hazır 🎉 Ödeme ile tamamını açabilirsin.',
                      style: TextStyle(color: Colors.lightGreenAccent.shade100, fontSize: 12),
                    ),
                  const SizedBox(height: 12),
                  const Text('Tutar: 49 ₺', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(
                    '+ vergiler',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.78),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Vergiler Google Play tarafından ödeme sırasında eklenir.',
                    style: TextStyle(color: Colors.white.withOpacity(0.70), fontSize: 11, height: 1.2),
                  ),
                  const SizedBox(height: 10),
                  if (!kReleaseMode)
                    Text(
                      'SKU: ${ProductCatalog.coffee49}',
                      style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12),
                    ),
                  if (_lastPaymentId != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Son işlem: $_lastPaymentId',
                      style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            GradientButton(
              text: _loading ? 'Ödeme işleniyor...' : 'Ödemeyi Tamamla ✨',
              onPressed: (_loading || _loadingReading) ? null : _pay,
            ),
          ],
        ),
      ),
    );
  }
}
