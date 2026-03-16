// mobile/lib/features/hand/hand_payment_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/hand_reading.dart';
import '../../services/device_id_service.dart';
import '../../services/iap_service.dart';
import '../../services/product_catalog.dart';
import '../../services/profile_store.dart'; // ✅ opsiyonel kişiselleştirme

import '../../services/hand_api.dart';
import 'hand_result_screen.dart';

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
  HandReading? _reading;
  bool _loadingReading = true;
  String? _loadError;

  static const bool debugUseStoreIap = false;

  String _titleSuffix = ''; // opsiyonel: profil adı

  @override
  void initState() {
    super.initState();
    _loadProfileName();
    _loadReading();
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

  bool _isReadyLockedOrDone(HandReading? r) {
    if (r == null) return false;
    if (r.hasResult) return true;
    final status = r.status.toLowerCase().trim();
    return status == 'completed' || status == 'done' || status == 'ready_locked' || status == 'ready_unlocked';
  }

  Future<void> _loadReading() async {
    setState(() {
      _loadingReading = true;
      _loadError = null;
    });
    try {
      final deviceId = await DeviceIdService.getOrCreate();
      final r = await HandApi.detail(deviceId: deviceId, readingId: widget.readingId);
      if (!mounted) return;
      setState(() => _reading = r);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = '$e');
    } finally {
      if (mounted) setState(() => _loadingReading = false);
    }
  }

  Future<void> _pay() async {
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
          sku: ProductCatalog.hand39,
        );

        if (!verify.verified) {
          throw Exception("Ödeme doğrulanamadı: ${verify.status}");
        }

        if (mounted) setState(() => _lastPaymentId = verify.paymentId);
      }

      HandReading? finalReading;
      for (var i = 0; i < 8; i++) {
        final rr = await HandApi.detail(deviceId: deviceId, readingId: widget.readingId);
        final txt = (rr.resultText ?? rr.comment ?? '').trim();
        if (txt.isNotEmpty) {
          finalReading = rr;
          break;
        }
        await Future.delayed(Duration(milliseconds: 500 + (i * 250)));
      }
      finalReading ??= await HandApi.detail(deviceId: deviceId, readingId: widget.readingId);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HandResultScreen(readingId: widget.readingId)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ödeme hatası: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
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
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ödemeyi tamamlayınca tüm el falını açıp okuyabilirsin.',
                      style: TextStyle(color: Colors.white.withOpacity(0.86), fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
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
