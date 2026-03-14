import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../services/coffee_api.dart';
import '../../services/device_id_service.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/mystic_scaffold.dart';

import 'coffee_result_screen.dart';
import '../home/home_screen.dart';

class CoffeeLoadingScreen extends StatefulWidget {
  final String readingId;
  const CoffeeLoadingScreen({super.key, required this.readingId});

  @override
  State<CoffeeLoadingScreen> createState() => _CoffeeLoadingScreenState();
}

class _CoffeeLoadingScreenState extends State<CoffeeLoadingScreen> {
  Timer? _timer;

  bool _done = false;
  bool _error = false;
  String? _errorMsg;

  int _elapsed = 0;
  static const int _pollSec = 2;

  bool _generateTriggered = false;
  String _lastStatus = '';

  static const int _hardWarnSec = 45;
  static const int _hardTimeoutSec = 180; // ✅ yeni: 3 dk sonra çıkış opsiyonu

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool _isConnectionAbort(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('connection abort') || s.contains('connection reset') ||
        s.contains('clientexception') || s.contains('socketexception') ||
        s.contains('software caused') || s.contains('499');
  }

  bool _asBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = (v ?? '').toString().toLowerCase().trim();
    return s == 'true' || s == '1' || s == 'yes';
  }

  Future<void> _startPolling() async {
    _timer?.cancel();
    _elapsed = 0;
    _timer = Timer.periodic(const Duration(seconds: _pollSec), (_) => _pollOnce());
    await _pollOnce();
  }

  Future<void> _pollOnce() async {
    if (_done) return;

    _elapsed += _pollSec;

    // ✅ hard timeout: kullanıcıyı sonsuza bırakma
    if (_elapsed >= _hardTimeoutSec) {
      if (mounted) {
        setState(() {
          _error = true;
          _errorMsg = "Zaman aşımı. Sunucu yanıtı gecikti. Ana sayfaya dönebilirsin.";
        });
      }
      return;
    }

    try {
      final deviceId = await DeviceIdService.getOrCreate();
      final d = await CoffeeApi.detailRaw(readingId: widget.readingId, deviceId: deviceId);

      final status = (d['status'] ?? '').toString().trim();
      final isPaid = _asBool(d['is_paid']);

      final text = ((d['comment'] ?? d['result_text']) ?? '').toString().trim();

      // ✅ En sağlam kural: text geldiyse iş bitmiştir (status’a güvenme)
      if (text.isNotEmpty) {
        _done = true;
        if (!mounted) return;

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => CoffeeResultScreen(resultText: text)),
          (route) => false,
        );
        return;
      }

      // ✅ processing -> paid dönüşü: generate yeniden tetiklenebilir
      final cameBackFromProcessing = (_lastStatus == 'processing' && status == 'paid');

      // ✅ ödeme doğrulandıysa generate tetikle (connection abort -> poll devam)
      if (isPaid && (!_generateTriggered || cameBackFromProcessing)) {
        if (status != 'processing') {
          try {
            _generateTriggered = true;
            await CoffeeApi.generate(readingId: widget.readingId, deviceId: deviceId);
          } catch (e) {
            if (_isConnectionAbort(e)) {
              _generateTriggered = false;
            } else {
              rethrow;
            }
          }
        }
      }

      _lastStatus = status;

      if (mounted) {
        setState(() {
          _error = false;
          _errorMsg = null;
        });
      }
    } catch (e) {
      if (mounted && !_isConnectionAbort(e)) {
        setState(() {
          _error = true;
          _errorMsg = e.toString();
        });
      }
    }
  }

  Future<void> _forceRetryGenerate() async {
    try {
      final deviceId = await DeviceIdService.getOrCreate();
      _generateTriggered = true;
      await CoffeeApi.generate(readingId: widget.readingId, deviceId: deviceId);
      if (mounted) {
        setState(() {
          _error = false;
          _errorMsg = null;
        });
      }
    } catch (e) {
      if (mounted && !_isConnectionAbort(e)) {
        setState(() {
          _error = true;
          _errorMsg = e.toString();
        });
      }
    }
  }

  Future<void> _goHomeWithToast() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Yorum üretilemedi. Ana sayfaya dönüldü.')),
    );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => HomeScreen()),
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
                      _error ? 'Bağlantı sorunu oluştu' : 'AI fincanınızı yorumluyor…',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error
                          ? (_errorMsg ?? 'Bilinmeyen hata')
                          : (hardWarn
                              ? 'Beklenenden uzun sürdü. İstersen yeniden tetikleyebilirsin.'
                              : 'Kişiselleştirilmiş yorumunuz hazırlanıyor.'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withOpacity(0.75), height: 1.25),
                    ),
                    const SizedBox(height: 16),
                    if (_error)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            setState(() {
                              _error = false;
                              _errorMsg = null;
                            });
                            await _startPolling();
                          },
                          child: const Text('Tekrar Dene'),
                        ),
                      ),
                    if (!_error && hardWarn) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _forceRetryGenerate,
                          child: const Text('Yeniden Tetikle'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _goHomeWithToast,
                          child: const Text('Ana Sayfa'),
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
