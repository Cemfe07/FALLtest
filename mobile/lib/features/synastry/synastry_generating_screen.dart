// lib/features/synastry/synastry_generating_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';

import '../../services/device_id_service.dart';
import '../../services/synastry_api.dart';
import '../profile/profile_screen.dart';
import 'synastry_payment_screen.dart';
import 'synastry_result_screen.dart';

class SynastryGeneratingScreen extends StatefulWidget {
  final String readingId;
  final String title;
  const SynastryGeneratingScreen({
    super.key,
    required this.readingId,
    this.title = 'Sinastri (Aşk Uyumu)',
  });

  @override
  State<SynastryGeneratingScreen> createState() => _SynastryGeneratingScreenState();
}

class _SynastryGeneratingScreenState extends State<SynastryGeneratingScreen> {
  final _api = SynastryApi();
  Timer? _timer;

  String _status = 'processing';
  String? _error;

  // ✅ NULL OLMASIN: her request'te zorunlu
  late final String _deviceId;

  bool _generateTriggered = false;
  bool _generateInFlight = false;
  String _lastStatus = '';

  int _elapsed = 0;
  static const int _pollSec = 2;

  static const int _warnSec = 18;
  static const int _hardWarnSec = 40;
  static const int _fallbackToProfileSec = 120;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _norm(String? s) => (s ?? '').toLowerCase().trim();

  bool _isDoneStatus(String s) {
    final x = _norm(s);
    return x == 'done' || x == 'completed' || x == 'complete';
  }

  bool _isErrorStatus(String s) => _norm(s) == 'error';

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

  bool _isRetryableGenerateError(Object e) {
    // “verify yansıma / işlem çakışması / anlık timing”
    return _isHttp(e, 402) || _isHttp(e, 409) ||
        e.toString().toLowerCase().contains('timeout') || _isConnectionAbort(e);
  }

  Future<void> _start() async {
    try {
      // ✅ deviceId kesin al
      _deviceId = await DeviceIdService.getOrCreate();

      _timer?.cancel();
      _elapsed = 0;

      // periyodik poll
      _timer = Timer.periodic(const Duration(seconds: _pollSec), (_) => _pollOnce());

      // hemen ilk poll
      await _pollOnce();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'error';
        _error = e.toString();
      });
    }
  }

  Future<void> _triggerGenerateSafely() async {
    if (_generateInFlight) return;
    _generateInFlight = true;

    // kontrollü retry/backoff
    const maxTry = 5;
    const baseDelayMs = 800;

    for (var i = 1; i <= maxTry; i++) {
      try {
        await _api.generate(
          widget.readingId,
          deviceId: _deviceId,
        );
        _generateInFlight = false;
        return;
      } catch (e) {
        final retryable = _isRetryableGenerateError(e);

        if (!mounted) {
          _generateInFlight = false;
          return;
        }

        if (retryable && i < maxTry) {
          if (i == 1 || i == 3) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_isConnectionAbort(e)
                    ? "Yorum hazırlanıyor, lütfen bekleyin…"
                    : "Analiz başlatılıyor… (tekrar deniyorum)"),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          await Future.delayed(Duration(milliseconds: baseDelayMs * i));
          continue;
        }

        if (_isConnectionAbort(e)) {
          if (mounted) setState(() => _generateTriggered = false);
          _generateInFlight = false;
          return;
        }

        // retry bitti -> ekranda hata
        setState(() {
          _status = 'error';
          _error = e.toString();
        });

        _generateInFlight = false;
        return;
      }
    }

    _generateInFlight = false;
  }

  Future<void> _pollOnce() async {
    _elapsed += _pollSec;
    if (_elapsed >= _fallbackToProfileSec) {
      _timer?.cancel();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const ProfileScreen(
            openWithMessage: "Yorumunuz arka planda hazırlanıyor. 'Benim Okumalarım' listesinde görünecek; aşağı çekerek yenileyebilirsiniz.",
          ),
        ),
        (route) => false,
      );
      return;
    }

    try {
      final s = await _api.getStatus(
        widget.readingId,
        deviceId: _deviceId,
      );

      if (!mounted) return;

      final st = _norm(s.status);
      final paid = (s.isPaid == true);
      final hasText = (s.resultText ?? '').trim().isNotEmpty;
      final ready = s.hasResult || _isDoneStatus(st);

      setState(() {
        _status = st.isEmpty ? 'processing' : st;
        _error = s.error;
      });

      // Ödeme yapılmış ve sonuç açılmışsa result ekranı
      if (paid && hasText) {
        _timer?.cancel();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SynastryResultScreen(
              readingId: widget.readingId,
              resultText: s.resultText ?? '',
            ),
          ),
        );
        return;
      }

      // Yorum hazırsa (kilitli) ödeme ekranına geç
      if (!paid && ready) {
        _timer?.cancel();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SynastryPaymentScreen(
              readingId: widget.readingId,
              title: widget.title,
            ),
          ),
        );
        return;
      }

      // backend "error" derse timerı kes
      if (_isErrorStatus(st)) {
        _timer?.cancel();
        return;
      }

      // ✅ generate tetik kuralı:
      // paid=true iken paid/started/processing durumlarında 1 kez tetikle
      // (senin "sonsuz bekleme" bug'ının sebebi processing'i tetiklememendi)
      final shouldTriggerGenerate =
          !ready && (st == 'paid' || st == 'started' || st == 'processing');

      // processing -> paid geri dönerse bir kez daha dene
      final cameBackToPaid = (_lastStatus == 'processing' && (st == 'paid' || st == 'started'));

      if (shouldTriggerGenerate && (!_generateTriggered || cameBackToPaid)) {
        _generateTriggered = true;
        await _triggerGenerateSafely();
      }

      _lastStatus = st;
    } catch (e) {
      if (!mounted) return;
      if (_isConnectionAbort(e)) return;
      setState(() {
        _status = 'error';
        _error = e.toString();
      });
      _timer?.cancel();
    }
  }

  Future<void> _retry() async {
    setState(() {
      _status = 'processing';
      _error = null;
      _generateTriggered = false;
      _generateInFlight = false;
      _lastStatus = '';
      _elapsed = 0;
    });
    await _start();
  }

  @override
  Widget build(BuildContext context) {
    final warn = _elapsed >= _warnSec;
    final hardWarn = _elapsed >= _hardWarnSec;

    final isError = _status == 'error';

    final msg = isError ? ('Hata: ${_error ?? "Bilinmeyen hata"}') : 'AI uyum analiziniz hazırlanıyor...';

    final sub = isError
        ? 'Tekrar deneyebilirsin.'
        : (hardWarn
            ? 'Beklenenden uzun sürdü. Yorum hazır olunca ödeme ekranına geçeceksin.'
            : (warn ? 'Bu analiz biraz uzun sürebilir. Birazdan hazır olacak.' : 'Genelde birkaç saniye içinde hazır olur.'));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hazırlanıyor'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isError)
                const SizedBox(
                  width: 52,
                  height: 52,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF6DD5FA),
                  ),
                )
              else
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 42),
              const SizedBox(height: 14),
              Text(
                msg,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, height: 1.3),
              ),
              const SizedBox(height: 10),
              Text(
                sub,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, height: 1.3),
              ),
              if (isError) ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD6B15E),
                    foregroundColor: Colors.black,
                  ),
                  onPressed: _retry,
                  child: const Text('Tekrar Dene'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
