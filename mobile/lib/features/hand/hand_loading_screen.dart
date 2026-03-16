// mobile/lib/features/hand/hand_loading_screen.dart
import 'package:flutter/material.dart';

import '../../models/hand_reading.dart';
import '../../services/device_id_service.dart';
import '../../services/hand_api.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/mystic_scaffold.dart';
import 'hand_payment_screen.dart';
import '../profile/profile_screen.dart';

class HandLoadingScreen extends StatefulWidget {
  final String readingId;
  const HandLoadingScreen({super.key, required this.readingId});

  @override
  State<HandLoadingScreen> createState() => _HandLoadingScreenState();
}

class _HandLoadingScreenState extends State<HandLoadingScreen> {
  String _statusText = 'El falın hazırlanıyor…';

  bool _isReady(HandReading r) {
    final status = r.status.toLowerCase().trim();
    return r.hasResult || status == 'completed' || status == 'done' || status == 'ready_locked' || status == 'ready_unlocked';
  }

  @override
  void initState() {
    super.initState();
    _run();
  }

  bool _isHttp(Object e, int code) {
    final s = e.toString();
    return s.contains(' $code ') || s.contains('$code /') || s.contains(':$code');
  }

  bool _isConnectionAbort(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('connection abort') || s.contains('connection reset') ||
        s.contains('clientexception') || s.contains('socketexception') ||
        s.contains('software caused') || _isHttp(e, 499);
  }

  String _extractUserMessage(Object e) {
    var msg = e.toString();
    msg = msg.replaceFirst('Exception: ', '').trim();

    // bazı throw formatlarında detail çok uzuyor -> kısa tut
    if (msg.toLowerCase().contains('payment required') || msg.contains('402')) {
      return 'Ödeme doğrulanıyor… (lütfen bekle)';
    }
    if (msg.toLowerCase().contains('upload hand photos') || msg.toLowerCase().contains('photos')) {
      return 'Fotoğraflar bulunamadı. Lütfen yeniden yükleyin.';
    }
    if (msg.toLowerCase().contains('avuç') || msg.toLowerCase().contains('palm')) {
      return 'Lütfen yalnızca avuç içi (palm) fotoğrafı yükleyin.';
    }
    return msg.isEmpty ? 'Bir hata oluştu.' : msg;
  }

  Future<void> _run() async {
    try {
      final deviceId = await DeviceIdService.getOrCreate();

      // ✅ güçlü retry/backoff
      const int maxTry = 8;
      const int baseDelayMs = 900;

      for (var i = 1; i <= maxTry; i++) {
        if (mounted) {
          setState(() {
            _statusText = 'Yorum hazırlanıyor… (deneme $i/$maxTry)';
          });
        }

        try {
          // 1) önce mevcut durumu çek
          var r = await HandApi.detail(deviceId: deviceId, readingId: widget.readingId);

          // ✅ zaten hazırsa direkt çık
          if (_isReady(r)) {
            break;
          }

          // 2) generate tetikle (arka plana alınca connection abort olabilir)
          try {
            await HandApi.generate(deviceId: deviceId, readingId: widget.readingId);
          } catch (e) {
            if (_isConnectionAbort(e)) {
              // Bağlantı koptu; sunucu tamamlamış olabilir - detail ile devam
            } else {
              rethrow;
            }
          }

          // 3) generate sonrası tekrar detail çek (DB güncellenmiş mi?)
          r = await HandApi.detail(deviceId: deviceId, readingId: widget.readingId);

          if (_isReady(r)) {
            break;
          }

          // ✅ bazı durumlarda status processing kalır; bekleyip retry
          if (i < maxTry) {
            await Future.delayed(Duration(milliseconds: baseDelayMs * i));
            continue;
          }
        } catch (e) {
          // ✅ 400: yanlış foto / validasyon -> retry YOK
          if (_isHttp(e, 400)) {
            throw Exception(_extractUserMessage(e));
          }

          // ✅ 402/409/429/500 + connection abort (arka plan)
          final retryable = _isHttp(e, 402) || _isHttp(e, 409) || _isHttp(e, 429) || _isHttp(e, 500) || _isConnectionAbort(e);

          if (retryable && i < maxTry) {
            if (mounted) {
              setState(() {
                _statusText = _extractUserMessage(e);
              });
            }
            await Future.delayed(Duration(milliseconds: baseDelayMs * i));
            continue;
          }

          throw Exception(_extractUserMessage(e));
        }
      }

      if (!mounted) return;

      // ✅ yeni akış: önce yorum hazırlansın, sonra ödeme/kilit ekranına geç
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HandPaymentScreen(readingId: widget.readingId)),
      );
    } catch (e) {
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const ProfileScreen(
            openWithMessage: "Yorumunuz arka planda hazırlanıyor. 'Benim Okumalarım' listesinde görünecek; aşağı çekerek yenileyebilirsiniz.",
          ),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MysticScaffold(
      scrimOpacity: 0.86,
      patternOpacity: 0.12,
      body: SafeArea(
        child: Center(
          child: SizedBox(
            width: 520,
            child: GlassCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _statusText,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lütfen uygulamadan çıkma 🙏',
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
