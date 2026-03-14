import 'dart:async';
import 'package:flutter/material.dart';

import '../../services/device_id_service.dart';
import '../../services/tarot_api.dart';
import '../../widgets/mystic_scaffold.dart';

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
  static const int _silentRetryStartSec = 35;  // 35sn sonra
  static const int _silentRetryEverySec = 18;  // 18sn'de bir tekrar dene
  int _lastSilentRetryAt = 0;

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
              _error ? 'Bağlantı sorunu oluştu' : 'AI tarot yorumunuz hazırlanıyor…',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            Text(
              _error
                  ? (_errorMsg ?? 'Bilinmeyen hata')
                  : 'Kişiselleştirilmiş yorumunuz hazırlanıyor. Lütfen bu ekranda kal.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.75), height: 1.25),
            ),

            const SizedBox(height: 16),

            // ✅ “Yeniden Tetikle” BUTONUNU kullanıcıya normalde göstermiyoruz.
            // Sadece gerçek bir hata varsa “Tekrar Dene” ve isterse tetikleme.
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
