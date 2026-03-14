import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/device_id_service.dart';
import '../../services/iap_service.dart';
import '../../services/product_catalog.dart';
import '../../services/numerology_api.dart';

import '../../widgets/glass_card.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/mystic_scaffold.dart';

import '../profile/profile_screen.dart';

class NumerologyPaymentScreen extends StatefulWidget {
  final String readingId;
  final String name;
  final String birthDate;
  final String question;

  const NumerologyPaymentScreen({
    super.key,
    required this.readingId,
    required this.name,
    required this.birthDate,
    required this.question,
  });

  @override
  State<NumerologyPaymentScreen> createState() => _NumerologyPaymentScreenState();
}

class _NumerologyPaymentScreenState extends State<NumerologyPaymentScreen> {
  bool _loading = false;
  String? _lastPaymentId;
  String _phase = 'idle';

  final String _sku = ProductCatalog.numerology299;
  static const bool debugUseStoreIap = false;

  void _fireGenerate() {
    DeviceIdService.getOrCreate().then((deviceId) {
      NumerologyApi.generate(readingId: widget.readingId, deviceId: deviceId).catchError((_) {});
    });
  }

  Future<void> _payAndContinue() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _phase = 'paying';
    });

    try {
      final deviceId = await DeviceIdService.getOrCreate();

      final shouldUseIap = kReleaseMode || debugUseStoreIap;

      if (shouldUseIap) {
        final verify = await IapService.instance.buyAndVerify(
          readingId: widget.readingId,
          sku: _sku,
        );

        if (!verify.verified) {
          throw Exception("Ödeme doğrulanamadı: ${verify.status}");
        }

        if (mounted) setState(() => _lastPaymentId = verify.paymentId);
      } else {
        final ref = "TEST-${DateTime.now().millisecondsSinceEpoch}";
        await NumerologyApi.markPaid(
          readingId: widget.readingId,
          paymentRef: ref,
          deviceId: deviceId,
        );
        if (mounted) setState(() => _lastPaymentId = ref);
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
        SnackBar(content: Text('Ödeme hatası: $e')),
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
      scrimOpacity: 0.70,
      patternOpacity: 0.22,
      appBar: AppBar(title: const Text('Ödeme')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Numeroloji Analizi",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Ad: ${widget.name}\n"
                    "Doğum: ${widget.birthDate}\n"
                    "Soru: ${widget.question.isEmpty ? "—" : widget.question}",
                    style: TextStyle(color: Colors.white.withOpacity(0.85), height: 1.25),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Tutar: 299 ₺",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "+ vergiler",
                    style: TextStyle(color: Colors.white.withOpacity(0.78), fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Vergiler Google Play tarafından ödeme sırasında eklenir.",
                    style: TextStyle(color: Colors.white.withOpacity(0.70), fontSize: 12, height: 1.2),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "SKU: $_sku",
                    style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12),
                  ),
                  if (_lastPaymentId != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      "Son işlem: $_lastPaymentId",
                      style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const Spacer(),
            GradientButton(
              text: _loading ? 'Ödeme işleniyor...' : 'Ödemeyi Başlat → Analizi Gör',
              onPressed: _loading ? null : _payAndContinue,
            ),
          ],
        ),
      ),
    );
  }
}
