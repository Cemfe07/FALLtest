import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/device_id_service.dart';
import '../../services/iap_service.dart';
import '../../services/product_catalog.dart';
import '../../widgets/mystic_scaffold.dart';

import '../../services/personality_api.dart';
import '../profile/profile_screen.dart';

class PersonalityPaymentScreen extends StatefulWidget {
  final String readingId;
  final String name;
  final String birthDate;
  final String birthTime;
  final String birthCity;
  final String birthCountry;
  final String question;

  const PersonalityPaymentScreen({
    super.key,
    required this.readingId,
    required this.name,
    required this.birthDate,
    required this.birthTime,
    required this.birthCity,
    required this.birthCountry,
    required this.question,
  });

  @override
  State<PersonalityPaymentScreen> createState() => _PersonalityPaymentScreenState();
}

class _PersonalityPaymentScreenState extends State<PersonalityPaymentScreen> {
  bool _loading = false;
  String? _lastPaymentId;
  String _phase = 'idle';

  final String _sku = ProductCatalog.personality399;
  static const bool debugUseStoreIap = false;

  void _fireGenerate() {
    DeviceIdService.getOrCreate().then((deviceId) {
      PersonalityApi.generate(readingId: widget.readingId, deviceId: deviceId).catchError((_) {});
    });
  }

  Future<void> _payAndContinue() async {
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

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        "$k: $v",
        style: TextStyle(color: Colors.white.withOpacity(0.85), height: 1.25),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MysticScaffold(
      scrimOpacity: 0.62,
      patternOpacity: 0.22,
      appBar: AppBar(title: const Text('Ödeme')),
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
                      "Kişilik Analizi",
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 10),
                    _row("Ad", widget.name),
                    _row("Doğum", widget.birthDate),
                    _row("Saat", widget.birthTime.isEmpty ? "—" : widget.birthTime),
                    _row("Yer", "${widget.birthCity}, ${widget.birthCountry}"),
                    _row("Not", widget.question.isEmpty ? "—" : widget.question),
                    const SizedBox(height: 10),
                    const Text("Tutar: 399 ₺", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
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
                    const SizedBox(height: 8),
                    Text("SKU: $_sku", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    if (_lastPaymentId != null) ...[
                      const SizedBox(height: 6),
                      Text("Son işlem: $_lastPaymentId", style: const TextStyle(color: Colors.white70, fontSize: 12)),
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
                  onPressed: _loading ? null : _payAndContinue,
                  child: _loading
                      ? const Text(
                          'Ödeme işleniyor...',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                        )
                      : const Text("Öde → Analizi Hazırla", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
