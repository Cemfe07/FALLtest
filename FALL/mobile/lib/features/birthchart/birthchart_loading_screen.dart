import 'dart:async';
import 'package:flutter/material.dart';

import '../../services/birthchart_api.dart';
import '../../services/device_id_service.dart';
import '../../widgets/mystic_scaffold.dart';
import 'birthchart_result_screen.dart';

class BirthChartLoadingScreen extends StatefulWidget {
  final String readingId;
  final String title;

  const BirthChartLoadingScreen({
    super.key,
    required this.readingId,
    this.title = "Doğum haritan hazırlanıyor...",
  });

  @override
  State<BirthChartLoadingScreen> createState() => _BirthChartLoadingScreenState();
}

class _BirthChartLoadingScreenState extends State<BirthChartLoadingScreen> {
  bool _running = false;

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

  String _prettyError(Object e) {
    final s = e.toString();

    if (_isHttp(e, 402)) {
      return "Ödeme doğrulaması sisteme henüz yansımadı.\n"
          "Birazdan otomatik tekrar deneyeceğim…";
    }

    if (_isHttp(e, 409)) {
      return "İşlem çakıştı / sonuç hazır değil.\n"
          "Tekrar deniyorum…";
    }

    if (s.toLowerCase().contains('timeout') || s.toLowerCase().contains('zaman')) {
      return "İşlem zaman aşımına uğradı.\n"
          "İnternetini kontrol edip tekrar dene.";
    }

    return "Bir hata oluştu:\n$s";
  }

  Future<void> _run() async {
    if (_running) return;
    _running = true;

    try {
      final deviceId = await DeviceIdService.getOrCreate();

      const maxTry = 8;
      const baseDelayMs = 900;

      for (var i = 1; i <= maxTry; i++) {
        if (!mounted) return;

        // 1) Önce detail ile hazır mı kontrol et (arka planda sunucu tamamlamış olabilir)
        try {
          final r = await BirthChartApi.detail(readingId: widget.readingId, deviceId: deviceId);
          final status = (r.status ?? '').toLowerCase();
          final text = (r.resultText ?? '').trim();
          if (text.isNotEmpty && (status == 'completed' || status == 'done')) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => BirthChartResultScreen(reading: r)),
              (route) => false,
            );
            return;
          }
        } catch (_) {}

        // 2) Generate tetikle (connection abort -> sonraki denemede detail ile alınır)
        try {
          final reading = await BirthChartApi.generate(
            readingId: widget.readingId,
            deviceId: deviceId,
          );

          if (!mounted) return;

          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => BirthChartResultScreen(reading: reading)),
            (route) => false,
          );
          return;
        } catch (e) {
          if (!mounted) return;

          final retryable = _isHttp(e, 402) || _isHttp(e, 409) || _isConnectionAbort(e);

          if (retryable && i < maxTry) {
            if (i == 1 || i == 3) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_isConnectionAbort(e)
                      ? "Yorum hazırlanıyor, lütfen bekleyin…"
                      : _prettyError(e)),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            await Future.delayed(Duration(milliseconds: baseDelayMs * i));
            continue;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_prettyError(e)), behavior: SnackBarBehavior.floating),
          );
          Navigator.of(context).pop();
          return;
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Yorum hazırlanamadı. Lütfen tekrar deneyin."), behavior: SnackBarBehavior.floating),
      );
      Navigator.of(context).pop();
    } finally {
      _running = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MysticScaffold(
      scrimOpacity: 0.72,
      patternOpacity: 0.18,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 14),
            Row(
              children: const [
                SizedBox(width: 16),
                Icon(Icons.auto_awesome, color: Colors.white),
                SizedBox(width: 10),
                Text(
                  "Analiz Oluşturuluyor",
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.50),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Semboller ve temalar birleştiriliyor…\n"
                      "Harita yerleşimleri yorumlanıyor…\n"
                      "Birazdan sana özel, uygulanabilir öneriler hazır.",
                      style: TextStyle(color: Colors.white.withOpacity(0.80), height: 1.35),
                    ),
                    const SizedBox(height: 16),
                    const Center(
                      child: SizedBox(
                        height: 28,
                        width: 28,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            const SizedBox(height: 26),
          ],
        ),
      ),
    );
  }
}
