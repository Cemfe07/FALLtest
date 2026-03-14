// mobile/lib/features/hand/hand_payment_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/device_id_service.dart';
import '../../services/hand_api.dart';
import '../../services/iap_service.dart';
import '../../services/product_catalog.dart';
import '../../services/profile_store.dart';

import '../profile/profile_screen.dart';

import '../../widgets/glass_card.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/mystic_scaffold.dart';

class HandPaymentScreen extends StatefulWidget {
  final String readingId;
  const HandPaymentScreen({super.key, required this.readingId});

  @override
  State<HandPaymentScreen> createState() => _HandPaymentScreenState();
}

class _HandPaymentScreenState extends State<HandPaymentScreen> {
  bool _loading = false;
  String? _lastPaymentId;

  // ✅ Debug modda store akışını test etmek istersen true
  static const bool debugUseStoreIap = false;

  String _titleSuffix = ''; // opsiyonel: profil adı

  @override
  void initState() {
    super.initState();
    _loadProfileName();
  }

  void _fireGenerate() {
    DeviceIdService.getOrCreate().then((deviceId) {
      HandApi.generate(deviceId: deviceId, readingId: widget.readingId).catchError((_) {});
    });
  }

  Future<void> _loadProfileName() async {
    try {
      await ProfileStore.instance.init(alsoSyncServer: true);
      final me = ProfileStore.instance.me;
      final name = (me?.displayName ?? '').trim();
      if (name.isNotEmpty && name != 'Misafir' && mounted) {
        setState(() => _titleSuffix = ' • $name');
      }
    } catch (_) {
      // sessiz geç
    }
  }

  Future<void> _pay() async {
    setState(() => _loading = true);
    try {
      // ✅ cihaz id hazır olsun
      await DeviceIdService.getOrCreate();

      final shouldUseIap = kReleaseMode || debugUseStoreIap;

      if (shouldUseIap) {
        final verify = await IapService.instance.buyAndVerify(
          readingId: widget.readingId,
          sku: ProductCatalog.hand39,
        );

        if (!verify.verified) {
          throw Exception("Ödeme doğrulanamadı: ${verify.status}");
        }

        if (mounted) setState(() => _lastPaymentId = verify.paymentId);
      }

      if (!mounted) return;

      // ✅ generate arka planda (fire-and-forget) – hata olsa bile devam
      _fireGenerate();

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
        (route) => false,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Ödemeniz alındı. Yorumunuz hazırlanıyor – Benim Okumalarım'dan ulaşabilirsiniz."),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ödeme/Yorum hatası: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MysticScaffold(
      appBar: AppBar(title: Text('Ödeme$_titleSuffix')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('El Falı', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  const Text(
                    'Avucundaki çizgiler, karakterin ve yolun hakkında küçük ipuçları taşır.\nŞimdi yorumlayalım.',
                  ),
                  const SizedBox(height: 12),
                  const Text('Tutar: 39 ₺', style: TextStyle(fontWeight: FontWeight.w800)),
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

                  // ✅ Release'te SKU göstermiyoruz
                  if (!kReleaseMode) ...[
                    const SizedBox(height: 10),
                    Text(
                      'SKU: ${ProductCatalog.hand39}',
                      style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12),
                    ),
                  ],

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
              text: _loading ? 'İşleniyor...' : 'Ödemeyi Tamamla ✨',
              onPressed: _loading ? null : _pay,
            ),
          ],
        ),
      ),
    );
  }
}
