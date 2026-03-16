import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/device_id_service.dart';
import '../../services/iap_service.dart';
import '../../services/product_catalog.dart';
import '../../services/numerology_api.dart';

import '../../models/numerology_reading.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/mystic_scaffold.dart';

import 'numerology_result_screen.dart';

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

  NumerologyReading? _reading;
  bool _loadingReading = true;
  String? _loadError;

  final String _sku = ProductCatalog.numerology299;
  static const bool debugUseStoreIap = false;

  bool _isReadyLockedOrDone(NumerologyReading? r) {
    if (r == null) return false;
    if (r.hasResult) return true;
    final s = r.status.toLowerCase().trim();
    return s == 'completed' || s == 'done' || s == 'ready_locked' || s == 'ready_unlocked';
  }

  @override
  void initState() {
    super.initState();
    _loadReading();
  }

  Future<void> _loadReading() async {
    setState(() {
      _loadingReading = true;
      _loadError = null;
    });
    try {
      final deviceId = await DeviceIdService.getOrCreate();
      final r = await NumerologyApi.get(readingId: widget.readingId, deviceId: deviceId);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Yorum durumu alınamadı: $e')),
      );
    }
  }

  void _fireGenerate() {
    // Yeni akışta generate zaten ödeme ÖNCESİ yapılmış halde geliyor.
    // Yine de güvenlik için, ödeme sonrası arka planda bir kez daha tetikleyebiliriz (idempotent).
    DeviceIdService.getOrCreate().then((deviceId) async {
      try {
        await NumerologyApi.generate(readingId: widget.readingId, deviceId: deviceId);
      } catch (_) {}
    });
  }

  Future<void> _payAndContinue() async {
    if (_loading) return;

    // Yorum hazır mı kontrol et; hazır değilse ödeme akışını başlatma.
    final text = (_reading?.resultText ?? '').trim();
    final readyByStatus = _isReadyLockedOrDone(_reading);
    if (text.isEmpty && !readyByStatus) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yorumun henüz hazır değil. Birkaç dakika içinde Profil > Benim Okumalarım’dan tekrar deneyebilirsin.')),
      );
      return;
    }
    setState(() {
      _loading = true;
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

      // Yorum zaten generate edilmiş durumda olmalı; ödeme sonrası
      // kilit açıldıktan sonra sonucu getirip direkt sonuç ekranına gidelim.
      _fireGenerate();
      if (!mounted) return;

      // Ödeme sonrası yorum metnini kısa polling ile çek.
      NumerologyReading? finalReading;
      for (var i = 0; i < 6; i++) {
        try {
          finalReading = await NumerologyApi.get(readingId: widget.readingId, deviceId: deviceId);
          if ((finalReading.resultText ?? '').trim().isNotEmpty) break;
        } catch (_) {}
        await Future.delayed(const Duration(seconds: 2));
      }

      final unlockedText = (finalReading?.resultText ?? _reading?.resultText ?? '').trim();
      if (unlockedText.isEmpty) {
        throw Exception("Yorum alınamadı, lütfen Profil > Benim Okumalarım'dan tekrar deneyin.");
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => NumerologyResultScreen(
            title: widget.question.isNotEmpty ? widget.question : 'Nümeroloji',
            resultText: unlockedText,
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ödeme hatası: $e')),
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
                  if (_loadingReading)
                    Row(
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Yorumun hazırlanma durumu kontrol ediliyor...",
                          style: TextStyle(color: Colors.white.withOpacity(0.80), fontSize: 12),
                        ),
                      ],
                    )
                  else if (_loadError != null)
                    Text(
                      "Yorum durumu alınamadı. Profil > Benim Okumalarım'dan kontrol edebilirsin.",
                      style: TextStyle(color: Colors.orange.shade200, fontSize: 12),
                    )
                  else if ((_reading?.resultText ?? '').trim().isEmpty && !_isReadyLockedOrDone(_reading))
                    Text(
                      "Yorumun henüz tamamen hazır değil. Hazır olduğunda bu ekrandan kilidi açabilirsin.",
                      style: TextStyle(color: Colors.white.withOpacity(0.80), fontSize: 12, height: 1.3),
                    )
                  else ...[
                    Text(
                      "Yorumun hazır 🎉",
                      style: TextStyle(color: Colors.white.withOpacity(0.90), fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Aşağıdaki ödeme adımı, hazır yorumu açmak içindir. Ödeme öncesinde yorumun üretimi tamamlandı.",
                      style: TextStyle(color: Colors.white.withOpacity(0.80), fontSize: 12, height: 1.3),
                    ),
                  ],
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
              onPressed: (_loading || _loadingReading) ? null : _payAndContinue,
            ),
          ],
        ),
      ),
    );
  }
}
