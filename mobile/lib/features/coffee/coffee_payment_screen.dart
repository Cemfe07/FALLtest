import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/device_id_service.dart';
import '../../services/iap_service.dart';
import '../../services/product_catalog.dart';
import '../../services/coffee_api.dart';

import '../profile/profile_screen.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/mystic_scaffold.dart';

class CoffeePaymentScreen extends StatefulWidget {
  final String readingId;
  const CoffeePaymentScreen({super.key, required this.readingId});

  @override
  State<CoffeePaymentScreen> createState() => _CoffeePaymentScreenState();
}

class _CoffeePaymentScreenState extends State<CoffeePaymentScreen> {
  bool _loading = false;
  String? _lastPaymentId;
  String _phase = 'idle';

  static const bool debugUseStoreIap = true;

  void _fireGenerate() {
    DeviceIdService.getOrCreate().then((deviceId) {
      CoffeeApi.generate(readingId: widget.readingId, deviceId: deviceId).catchError((_) {});
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
    setState(() {
      _loading = true;
      _phase = 'paying';
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
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
        (route) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Ödemeniz alındı. Yorumunuz hazırlanıyor – Benim Okumalarım'dan ulaşabilirsiniz."),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ödeme/Yorum hatası: $e')),
      );
    } finally {
      if (mounted) setState(() {
        _loading = false;
        _phase = 'idle';
      });
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
                  const Text('Falını başlatmak için ödeme adımını tamamla.'),
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
              onPressed: _loading ? null : _pay,
            ),
          ],
        ),
      ),
    );
  }
}
