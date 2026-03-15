import 'dart:async';
import 'package:flutter/material.dart';

import '../../services/device_id_service.dart';
import '../../services/tarot_api.dart';
import '../../widgets/mystic_scaffold.dart';

import '../profile/profile_screen.dart';
import 'tarot_models.dart';
import 'tarot_result_screen.dart';

class TarotProcessingScreen extends StatefulWidget {
  final String readingId;
  final String question;
  final TarotSpreadType spreadType;
  final List<TarotCard> selectedCards;

  const TarotProcessingScreen({
    super.key,
    required this.readingId,
    required this.question,
    required this.spreadType,
    required this.selectedCards,
  });

  @override
  State<TarotProcessingScreen> createState() => _TarotProcessingScreenState();
}

class _TarotProcessingScreenState extends State<TarotProcessingScreen> {
  Timer? _timer;

  bool _done = false;

  // Kullanıcıya sadece gerçek hata olursa göster
  bool _error = false;
  String? _errorMsg;

  int _elapsed = 0;
  static const int _pollSec = 2;

  bool _generateTriggered = false;
  String _lastStatus = '';

  // ✅ Kullanıcıyı tedirgin etmeyelim:
  // Uyarı metni yok. Sadece uzun sürerse içeride sessiz retry yapacağız.
  static const int _silentRetryStartSec = 25;
  static const int _silentRetryEverySec = 15;
  int _lastSilentRetryAt = 0;
  static const int _showAlternativesAfterSec = 90;  // 90 sn sonra "Profil'e git" göster

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

  Future<void> _startPolling() async {
    _timer?.cancel();
    _elapsed = 0;
    _lastSilentRetryAt = 0;
    _timer = Timer.periodic(const Duration(seconds: _pollSec), (_) => _pollOnce());
    await _pollOnce();
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

  Future<void> _pollOnce() async {
    if (_done) return;

    _elapsed += _pollSec;

    try {
      final deviceId = await DeviceIdService.getOrCreate();
      final d = await TarotApi.detail(readingId: widget.readingId, deviceId: deviceId);

      final status = (d['status'] ?? '').toString().trim();
      final text = (d['result_text'] ?? '').toString().trim();
      final isPaid = _asBool(d['is_paid']);

      // ✅ Sonuç geldiyse bitir
      if (status == 'completed' && text.isNotEmpty) {
        _done = true;
        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => TarotResultScreen(
              question: widget.question,
              spreadType: widget.spreadType,
              selectedCards: widget.selectedCards,
              resultText: text,
            ),
          ),
        );
        return;
      }

      // ✅ is_paid == true ise generate tetiklenebilir
      final cameBackFromProcessing =
          (_lastStatus == 'processing' && (status == 'paid' || status == 'selected'));

      // 1) İlk tetikleme (connection abort -> sonraki poll tekrar dener)
      if (isPaid && (!_generateTriggered || cameBackFromProcessing)) {
        if (status != 'processing') {
          try {
            _generateTriggered = true;
            await TarotApi.generate(readingId: widget.readingId, deviceId: deviceId);
          } catch (e) {
            if (_isConnectionAbort(e)) _generateTriggered = false;
            else rethrow;
          }
        }
      }

      // 2) Sessiz otomatik retry
      // Uzun sürerse, belirli aralıklarla generate’i tekrar dene.
      if (isPaid &&
          _elapsed >= _silentRetryStartSec &&
          (_elapsed - _lastSilentRetryAt) >= _silentRetryEverySec) {
        // processing'te takılı kalmasın diye:
        // status processing değilse generate dene
        if (status != 'processing') {
          try {
            _lastSilentRetryAt = _elapsed;
            _generateTriggered = true;
            await TarotApi.generate(readingId: widget.readingId, deviceId: deviceId);
          } catch (e) {
            if (_isConnectionAbort(e)) _generateTriggered = false;
            else rethrow;
          }
        }
      }

      _lastStatus = status;

      // ✅ Sorunsuz polling -> kullanıcıya hata gösterme
      if (mounted && _error) {
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
      await TarotApi.generate(readingId: widget.readingId, deviceId: deviceId);
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

  @override
  Widget build(BuildContext context) {
    return MysticScaffold(
      scrimOpacity: 0.84,
      patternOpacity: 0.16,
      appBar: AppBar(title: const Text('İşleniyor')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: _error ? null : const Color(0xFF6DD5FA),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              _error ? 'Bağlantı sorunu oluştu' : 'Yorumunuz hazırlanıyor',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _error
                  ? (_errorMsg ?? 'Bilinmeyen hata')
                  : 'Adım 1: Ödeme alındı ✓\nAdım 2: AI yorumu oluşturuluyor…\nLütfen bu ekranda kalın.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.85), height: 1.4, fontSize: 14),
            ),
            if (!_error && _elapsed > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Beklenen süre: ~$_elapsed sn',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),

            const SizedBox(height: 20),

            if (_elapsed >= _showAlternativesAfterSec && !_error) ...[
              Text(
                'Yorum biraz gecikiyorsa aşağıdan tekrar deneyin veya Profil\'e gidip bildirim bekleyin.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.amber.shade200, fontSize: 12, height: 1.3),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: _forceRetryGenerate,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Tekrar dene'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const ProfileScreen()),
                        (r) => false,
                      );
                    },
                    icon: const Icon(Icons.person_outline, size: 18),
                    label: const Text("Profil'e git"),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

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

            if (_error) const SizedBox(height: 10),

            if (_error)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _forceRetryGenerate,
                  child: const Text('Yeniden Başlat'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
