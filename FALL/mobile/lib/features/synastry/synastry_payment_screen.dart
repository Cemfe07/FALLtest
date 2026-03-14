import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/device_id_service.dart';
import '../../services/iap_service.dart';
import '../../services/product_catalog.dart';
import '../../services/synastry_api.dart';

import '../profile/profile_screen.dart';

import '../../widgets/mystic_scaffold.dart';

class SynastryPaymentScreen extends StatefulWidget {
  final String readingId;
  final String title;

  const SynastryPaymentScreen({
    super.key,
    required this.readingId,
    required this.title,
  });

  @override
  State<SynastryPaymentScreen> createState() => _SynastryPaymentScreenState();
}

class _SynastryPaymentScreenState extends State<SynastryPaymentScreen> {
  bool _loading = false;
  String? _lastPaymentId;

  // sadece debug için: hangi device ile gidiyoruz gör
  String? _deviceId;

  final String _sku = ProductCatalog.synastry149;

  // Debug'da store test etmek istersen true
  static const bool debugUseStoreIap = false;

  void _fireGenerate() {
    final api = SynastryApi();
    DeviceIdService.getOrCreate().then((deviceId) {
      api.generate(widget.readingId, deviceId: deviceId).catchError((_) {});
    });
  }

  Future<void> _payAndStart() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      // ✅ KRİTİK: device id’yi al ve sakla
      final deviceId = await DeviceIdService.getOrCreate();
      if (mounted) setState(() => _deviceId = deviceId);

      final shouldUseIap = kReleaseMode || debugUseStoreIap;

      if (shouldUseIap) {
        // ✅ IapService’in verify çağrısı backend’e X-Device-Id göndermeli.
        // IapService içinde ApiBase.headers(deviceId: deviceId) kullanmıyorsan,
        // orayı da güncellememiz gerekir.
        final verify = await IapService.instance.buyAndVerify(
          readingId: widget.readingId,
          sku: _sku,
        );

        if (!verify.verified) {
          throw Exception("Ödeme doğrulanamadı: ${verify.status}");
        }

        if (mounted) setState(() => _lastPaymentId = verify.paymentId);
      }

      if (!mounted) return;
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
        SnackBar(content: Text('Ödeme hatası: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MysticScaffold(
      scrimOpacity: 0.62,
      patternOpacity: 0.22,
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Sinastri (Uyum Analizi)",
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Ödeme doğrulandıktan sonra analiz üretimine geçilir.",
                      style: TextStyle(color: Colors.white70, height: 1.25),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Tutar: 149 ₺",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "+ vergiler",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.78),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Vergiler Google Play tarafından ödeme sırasında eklenir.",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.70),
                        fontSize: 12,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text("SKU: $_sku", style: const TextStyle(color: Colors.white70, fontSize: 12)),

                    if (_lastPaymentId != null) ...[
                      const SizedBox(height: 6),
                      Text("Son işlem: $_lastPaymentId", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],

                    // sadece debug amaçlı
                    if (!kReleaseMode && _deviceId != null) ...[
                      const SizedBox(height: 6),
                      Text("Device: $_deviceId", style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    ],

                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF5C361),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _loading ? null : _payAndStart,
                  child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text(
                          "Öde → Analizi Başlat",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
