import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/device_id_service.dart';
import '../../services/personality_api.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/mystic_loading_indicator.dart';
import '../../widgets/mystic_scaffold.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import 'personality_payment_screen.dart';
import 'personality_result_screen.dart';

class PersonalityGeneratingScreen extends StatefulWidget {
  final String readingId;
  final String name;
  final String birthDate;
  final String birthTime;
  final String birthCity;
  final String birthCountry;
  final String question;
  const PersonalityGeneratingScreen({
    super.key,
    required this.readingId,
    this.name = '',
    this.birthDate = '',
    this.birthTime = '',
    this.birthCity = '',
    this.birthCountry = 'TR',
    this.question = '',
  });

  @override
  State<PersonalityGeneratingScreen> createState() => _PersonalityGeneratingScreenState();
}

class _PersonalityGeneratingScreenState extends State<PersonalityGeneratingScreen> {
  String _statusText = 'Kişilik analizin hazırlanıyor…';
  bool _loading = true;

  Timer? _timer;
  int _ticks = 0;

  static const Duration _pollEvery = Duration(seconds: 2);
  static const int _maxTicks = 90; // ~3dk (kötü ağlarda daha iyi)

  bool _isReady(PersonalityReading r) {
    final status = r.status.toLowerCase().trim();
    return r.hasResult || status == 'done' || status == 'completed' || status == 'ready_locked' || status == 'ready_unlocked';
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

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

  Future<void> _start() async {
    if (!mounted) return;

    // ✅ reset
    _ticks = 0;

    setState(() {
      _loading = true;
      _statusText = 'Kişilik analizin hazırlanıyor…';
    });

    // ✅ generate'i bir kez tetikle (backend artık hemen dönecek)
    try {
      final deviceId = await DeviceIdService.getOrCreate();
      await PersonalityApi.generate(readingId: widget.readingId, deviceId: deviceId);
    } catch (_) {
      // generate 402/403 vs olsa bile polling ile anlaşılır; sessiz geç
    }

    _timer?.cancel();
    _timer = Timer.periodic(_pollEvery, (_) => _poll());
  }

  Future<void> _poll() async {
    if (!mounted) return;

    _ticks += 1;

    if (_ticks > _maxTicks) {
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
      final deviceId = await DeviceIdService.getOrCreate();
      final r = await PersonalityApi.detail(readingId: widget.readingId, deviceId: deviceId);

      final status = r.status.toLowerCase().trim();
      final result = (r.resultText ?? '').trim();
      final ready = _isReady(r);

      // Ödeme yapılmış ve sonuç açılmışsa sonuç ekranı
      if (r.isPaid && result.isNotEmpty) {
        _timer?.cancel();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => PersonalityResultScreen(readingId: widget.readingId)),
          (route) => false,
        );
        return;
      }

      // Yorum hazırsa (kilitli), ödeme ekranına geç
      if (!r.isPaid && ready) {
        _timer?.cancel();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PersonalityPaymentScreen(
              readingId: widget.readingId,
              name: widget.name,
              birthDate: widget.birthDate,
              birthTime: widget.birthTime,
              birthCity: widget.birthCity,
              birthCountry: widget.birthCountry,
              question: widget.question,
            ),
          ),
        );
        return;
      }

      // UI mesajı
      setState(() {
        _loading = true;

        if (status == 'processing') {
          _statusText = 'Analiz hazırlanıyor… ($_ticks/$_maxTicks)';
        } else if (status == 'started' || status == 'created' || status == 'pending_payment') {
          _statusText = 'Analiz başlatıldı… ($_ticks/$_maxTicks)';
        } else {
          _statusText = 'İşlem sürüyor… ($_ticks/$_maxTicks)';
        }
      });
    } catch (_) {
      // ağ dalgalanması → devam
      if (!mounted) return;
      setState(() {
        _loading = true;
        _statusText = 'Bağlantı kontrol ediliyor… ($_ticks/$_maxTicks)';
      });
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
                  MysticLoadingIndicator(
                    message: _statusText,
                    submessage: 'Lütfen uygulamadan çıkmayın',
                    size: 100,
                  ),
                  if (!_loading) ...[
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: _goHome,
                      child: const Text('Ana sayfaya dön'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
