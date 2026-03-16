import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/synastry_models.dart';
import '../../services/device_id_service.dart';
import '../../services/iap_service.dart';
import '../../services/product_catalog.dart';

import '../../services/synastry_api.dart';
import '../../widgets/mystic_scaffold.dart';
import 'synastry_result_screen.dart';

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
  bool _loadingReading = true;
  String? _lastPaymentId;
  SynastryStatusResponse? _reading;
  String? _loadError;
  String? _deviceId;

  final String _sku = ProductCatalog.synastry149;

  // Debug'da store test etmek istersen true
  static const bool debugUseStoreIap = false;
  
  @override
  void initState() {
    super.initState();
    _loadReading();
  }

  bool _isReadyLockedOrDone(SynastryStatusResponse? r) {
    if (r == null) return false;
    if (r.hasResult) return true;
    final s = r.status.toLowerCase().trim();
    return s == 'done' || s == 'completed' || s == 'ready_locked' || s == 'ready_unlocked';
  }

  Future<void> _loadReading() async {
    setState(() {
      _loadingReading = true;
      _loadError = null;
    });
    try {
      final did = await DeviceIdService.getOrCreate();
      if (mounted) setState(() => _deviceId = did);
      final api = SynastryApi();
      final r = await api.getStatus(widget.readingId, deviceId: did);
      if (!mounted) return;
      setState(() => _reading = r);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = '$e');
    } finally {
      if (mounted) setState(() => _loadingReading = false);
    }
  }

  Future<void> _payAndStart() async {
    if (_loading) return;
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
      } else {
        final api = SynastryApi();
        await api.markPaid(
          widget.readingId,
          paymentRef: 'TEST-DEBUG',
          deviceId: deviceId,
        );
      }

      final api = SynastryApi();
      SynastryStatusResponse? finalReading;
      for (var i = 0; i < 8; i++) {
        final rr = await api.getStatus(widget.readingId, deviceId: deviceId);
        final txt = (rr.resultText ?? '').trim();
        if (txt.isNotEmpty) {
          finalReading = rr;
          break;
        }
        await Future.delayed(Duration(milliseconds: 500 + (i * 250)));
      }
      finalReading ??= await api.getStatus(widget.readingId, deviceId: deviceId);
      final resultText = (finalReading.resultText ?? '').trim();
      if (resultText.isEmpty) {
        throw Exception('Yorum metni henüz açılamadı. Lütfen tekrar dene.');
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SynastryResultScreen(
            readingId: widget.readingId,
            resultText: resultText,
          ),
        ),
      );
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
                    Text(
                      "Yorumun hazır olduğunda kilidi açarsın.",
                      style: TextStyle(color: Colors.white.withOpacity(0.82), height: 1.25),
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

                    const SizedBox(height: 12),
                    if (_loadingReading)
                      Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Yorum durumu kontrol ediliyor...',
                            style: TextStyle(color: Colors.white.withOpacity(0.82), fontSize: 12),
                          ),
                        ],
                      )
                    else if (_loadError != null)
                      Text(
                        'Durum alınamadı: $_loadError',
                        style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12),
                      )
                    else if ((_reading?.resultText ?? '').trim().isEmpty && !_isReadyLockedOrDone(_reading))
                      Text(
                        'Yorumun henüz tamamen hazır değil. Hazır olduğunda bu ekrandan kilidi açabilirsin.',
                        style: TextStyle(color: Colors.white.withOpacity(0.90), fontSize: 13),
                      )
                    else ...[
                      const Text(
                        'Yorumun hazır 🎉',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ödemeyi tamamlayınca sinastri yorumunun tamamı açılır.',
                        style: TextStyle(color: Colors.white.withOpacity(0.86), fontSize: 12),
                      ),
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
                  onPressed: (_loading || _loadingReading) ? null : _payAndStart,
                  child: _loading
                      ? const Text(
                          'Ödeme işleniyor...',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                        )
                      : const Text(
                          "Ödemeyi Tamamla ✨",
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
