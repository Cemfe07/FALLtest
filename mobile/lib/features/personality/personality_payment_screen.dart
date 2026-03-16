import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/device_id_service.dart';
import '../../services/iap_service.dart';
import '../../services/product_catalog.dart';
import '../../widgets/mystic_scaffold.dart';

import '../../services/personality_api.dart';
import 'personality_result_screen.dart';

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
  bool _loadingReading = true;
  String? _lastPaymentId;
  PersonalityReading? _reading;
  String? _loadError;

  final String _sku = ProductCatalog.personality399;
  static const bool debugUseStoreIap = false;
  
  @override
  void initState() {
    super.initState();
    _loadReading();
  }

  bool _isReadyLockedOrDone(PersonalityReading? r) {
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
      final deviceId = await DeviceIdService.getOrCreate();
      final r = await PersonalityApi.detail(readingId: widget.readingId, deviceId: deviceId);
      if (!mounted) return;
      setState(() => _reading = r);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = '$e');
    } finally {
      if (mounted) setState(() => _loadingReading = false);
    }
  }

  Future<void> _payAndContinue() async {
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
        await PersonalityApi.markPaid(
          readingId: widget.readingId,
          paymentRef: 'TEST-DEBUG',
          deviceId: deviceId,
        );
      }

      PersonalityReading? finalReading;
      for (var i = 0; i < 8; i++) {
        final rr = await PersonalityApi.detail(readingId: widget.readingId, deviceId: deviceId);
        final txt = (rr.resultText ?? '').trim();
        if (txt.isNotEmpty) {
          finalReading = rr;
          break;
        }
        await Future.delayed(Duration(milliseconds: 500 + (i * 250)));
      }
      finalReading ??= await PersonalityApi.detail(readingId: widget.readingId, deviceId: deviceId);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => PersonalityResultScreen(readingId: widget.readingId)),
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
                        'Ödemeyi tamamlayınca kişilik analizinin tamamı açılır.',
                        style: TextStyle(color: Colors.white.withOpacity(0.86), fontSize: 12),
                      ),
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
                  onPressed: (_loading || _loadingReading) ? null : _payAndContinue,
                  child: _loading
                      ? const Text(
                          'Ödeme işleniyor...',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                        )
                      : const Text("Ödemeyi Tamamla ✨", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
