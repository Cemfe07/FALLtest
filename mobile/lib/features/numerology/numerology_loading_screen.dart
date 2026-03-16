import 'package:flutter/material.dart';

import 'package:lunaura/widgets/mystic_scaffold.dart';
import 'package:lunaura/services/device_id_service.dart';
import 'package:lunaura/services/numerology_api.dart';
import 'package:lunaura/models/numerology_reading.dart';
import 'package:lunaura/features/numerology/numerology_payment_screen.dart';
import 'package:lunaura/features/profile/profile_screen.dart';

class NumerologyLoadingScreen extends StatefulWidget {
  final String readingId;
  final String title;
  final String name;
  final String birthDate;
  final String question;

  const NumerologyLoadingScreen({
    super.key,
    required this.readingId,
    required this.title,
    required this.name,
    required this.birthDate,
    required this.question,
  });

  @override
  State<NumerologyLoadingScreen> createState() => _NumerologyLoadingScreenState();
}

class _NumerologyLoadingScreenState extends State<NumerologyLoadingScreen> {
  String _hint = "AI analiziniz hazırlanıyor…";

  bool _isReady(NumerologyReading? r) {
    if (r == null) return false;
    final s = (r.status).toLowerCase().trim();
    return r.hasResult || s == 'completed' || s == 'done' || s == 'ready_locked' || s == 'ready_unlocked';
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

  Future<void> _run() async {
    try {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _hint = "AI sayıların dilini çözüyor…");
      });
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) setState(() => _hint = "Kişiselleştirilmiş temalar birleştiriliyor…");
      });

      final deviceId = await DeviceIdService.getOrCreate();

      const maxTry = 8;
      const baseDelayMs = 900;

      NumerologyReading? generated;

      for (var i = 1; i <= maxTry; i++) {
        if (!mounted) return;
        setState(() => _hint = "Yorum hazırlanıyor… (deneme $i/$maxTry)");

        try {
          generated = await NumerologyApi.generate(
            readingId: widget.readingId,
            deviceId: deviceId,
          );
          if (_isReady(generated)) {
            break;
          }
        } catch (e) {
          if (_isConnectionAbort(e)) {
            if (i < maxTry) {
              await Future.delayed(Duration(milliseconds: baseDelayMs * i));
              continue;
            }
          }
          final retryable = _isHttp(e, 402) || _isHttp(e, 409) || _isHttp(e, 500);
          if (retryable && i < maxTry) {
            await Future.delayed(Duration(milliseconds: baseDelayMs * i));
            continue;
          }
          rethrow;
        }
      }

      if (!mounted) return;
      if (!_isReady(generated)) {
        try {
          generated = await NumerologyApi.get(readingId: widget.readingId, deviceId: deviceId);
        } catch (_) {}
      }
      if (_isReady(generated)) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => NumerologyPaymentScreen(
              readingId: widget.readingId,
              name: widget.name,
              birthDate: widget.birthDate,
              question: widget.question,
            ),
          ),
        );
      } else {
        throw Exception("Yorum hazırlanamadı. Lütfen tekrar deneyin.");
      }
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
      scrimOpacity: 0.62,
      patternOpacity: 0.22,
      body: Container(
        color: const Color(0xFF1a0a1f),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 14),
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.50),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "Analiz Oluşturuluyor",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const SizedBox(
                        height: 40,
                        width: 40,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF6DD5FA),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _hint,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.90),
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Sayıların dilini çözüyoruz…\nBirazdan kişiselleştirilmiş yorumun hazır.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.70),
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
