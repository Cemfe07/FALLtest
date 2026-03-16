import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../services/coffee_api.dart';
import '../../services/device_id_service.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/mystic_scaffold.dart';

import 'coffee_payment_screen.dart';
import '../profile/profile_screen.dart';

class CoffeeLoadingScreen extends StatefulWidget {
  final String readingId;
  const CoffeeLoadingScreen({super.key, required this.readingId});

  @override
  State<CoffeeLoadingScreen> createState() => _CoffeeLoadingScreenState();
}

class _CoffeeLoadingScreenState extends State<CoffeeLoadingScreen> {
  bool _running = false;
  bool _error = false;
  String? _errorMsg;
  int _elapsed = 0;
  static const int _hardWarnSec = 45;
  static const int _hardTimeoutSec = 180;
  String _hint = 'AI fincanınızı yorumluyor…';

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    super.dispose();
  }

  bool _isConnectionAbort(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('connection abort') || s.contains('connection reset') ||
        s.contains('clientexception') || s.contains('socketexception') ||
        s.contains('software caused') || s.contains('499');
  }

  bool _isReadyFromDetail(Map<String, dynamic> d) {
    final hasResult = d['has_result'] == true;
    final status = (d['status'] ?? '').toString().toLowerCase().trim();
    return hasResult || status == 'completed' || status == 'done' || status == 'ready_locked';
  }

  Future<void> _run() async {
    if (_running) return;
    _running = true;

    try {
      final deviceId = await DeviceIdService.getOrCreate();
      const maxTry = 10;
      const baseDelayMs = 900;

      for (var i = 1; i <= maxTry; i++) {
        if (!mounted) return;

        setState(() {
          _elapsed = (i * baseDelayMs / 1000).round();
          _hint = "Yorum hazırlanıyor… (deneme $i/$maxTry)";
        });

        Map<String, dynamic>? d;
        try {
          d = await CoffeeApi.detailRaw(readingId: widget.readingId, deviceId: deviceId);
        } catch (_) {}

        if (d != null && _isReadyFromDetail(d)) {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => CoffeePaymentScreen(readingId: widget.readingId)),
          );
          return;
        }

        try {
          await CoffeeApi.generate(readingId: widget.readingId, deviceId: deviceId);
        } catch (e) {
          if (!_isConnectionAbort(e) && mounted && i == maxTry) {
            setState(() {
              _error = true;
              _errorMsg = e.toString();
            });
            return;
          }
        }

        if (_elapsed >= _hardTimeoutSec) {
          if (!mounted) return;
          setState(() {
            _error = true;
            _errorMsg = "Zaman aşımı. Yorum henüz hazır değil, Benim Okumalarım'dan takip edebilirsin.";
          });
          return;
        }

        await Future.delayed(Duration(milliseconds: baseDelayMs * i));
      }

      if (!mounted) return;
      setState(() {
        _error = true;
        _errorMsg = "Yorum henüz tamamlanamadı. Benim Okumalarım'dan takip edebilirsin.";
      });
    } catch (e) {
      if (mounted && !_isConnectionAbort(e)) {
        setState(() {
          _error = true;
          _errorMsg = e.toString();
        });
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _goToProfileWithMessage() async {
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

  @override
  Widget build(BuildContext context) {
    final hardWarn = _elapsed >= _hardWarnSec;

    return MysticScaffold(
      scrimOpacity: 0.86,
      patternOpacity: 0.12,
      appBar: AppBar(title: const Text('İşleniyor')),
      body: SafeArea(
        child: Center(
          child: SizedBox(
            width: 520,
            child: GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 56,
                      height: 56,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: _error ? null : AppColors.aiAccent,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _error ? 'Yorum henüz hazır değil' : 'AI fincanınızı yorumluyor…',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error
                          ? (_errorMsg ?? 'Bilinmeyen hata')
                          : (hardWarn
                              ? 'Beklenenden uzun sürdü. Hazır olduğunda otomatik ödeme adımına geçeceksin.'
                              : _hint),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withOpacity(0.75), height: 1.25),
                    ),
                    const SizedBox(height: 16),
                    if (_error) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            setState(() {
                              _error = false;
                              _errorMsg = null;
                            });
                            await _run();
                          },
                          child: const Text('Tekrar Dene'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _goToProfileWithMessage,
                          child: const Text('Benim Okumalarım\'a Git'),
                        ),
                      ),
                    ],
                    if (!_error && hardWarn) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _goToProfileWithMessage,
                          child: const Text('Benim Okumalarım\'a Git'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
