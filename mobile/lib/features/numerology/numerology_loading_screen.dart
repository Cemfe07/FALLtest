import 'package:flutter/material.dart';

import 'package:lunaura/widgets/mystic_scaffold.dart';
import 'package:lunaura/services/device_id_service.dart';
import 'package:lunaura/services/numerology_api.dart';
import 'package:lunaura/models/numerology_reading.dart';
import 'package:lunaura/features/numerology/numerology_result_screen.dart';

class NumerologyLoadingScreen extends StatefulWidget {
  final String readingId;
  final String title;

  const NumerologyLoadingScreen({
    super.key,
    required this.readingId,
    required this.title,
  });

  @override
  State<NumerologyLoadingScreen> createState() => _NumerologyLoadingScreenState();
}

class _NumerologyLoadingScreenState extends State<NumerologyLoadingScreen> {
  String _hint = "AI analiziniz hazırlanıyor…";

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
          final r = await NumerologyApi.get(readingId: widget.readingId, deviceId: deviceId);
          final status = (r.status ?? '').toLowerCase();
          final text = (r.resultText ?? '').trim();
          if (text.isNotEmpty && (status == 'completed' || status == 'done')) {
            generated = r;
            break;
          }
        } catch (_) {}

        try {
          generated = await NumerologyApi.generate(
            readingId: widget.readingId,
            deviceId: deviceId,
          );
          break;
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
      if (generated != null && (generated!.resultText ?? '').trim().isNotEmpty) {
        Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => NumerologyResultScreen(
            title: widget.title,
            resultText: generated!.resultText ?? "",
          ),
        ),
      );
      } else {
        throw Exception("Yorum hazırlanamadı. Lütfen tekrar deneyin.");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MysticScaffold(
      scrimOpacity: 0.62,
      patternOpacity: 0.22,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
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
            const SizedBox(
              height: 46,
              width: 46,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Color(0xFF6DD5FA),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _hint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Spacer(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
