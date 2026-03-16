import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/device_id_service.dart';
import '../../services/iap_service.dart';
import '../../services/product_catalog.dart';
import '../../services/tarot_api.dart';

import '../../widgets/glass_card.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/mystic_scaffold.dart';

import 'tarot_deck.dart';
import 'tarot_models.dart';
import 'tarot_result_screen.dart';

class TarotPaymentScreen extends StatefulWidget {
  final String readingId;
  final String? question;
  final TarotSpreadType? spreadType;
  final List<TarotCard> selectedCards;

  const TarotPaymentScreen({
    super.key,
    required this.readingId,
    this.question,
    this.spreadType,
    this.selectedCards = const [],
  });

  @override
  State<TarotPaymentScreen> createState() => _TarotPaymentScreenState();
}

class _TarotPaymentScreenState extends State<TarotPaymentScreen> {
  bool _loading = false;
  bool _loadingReading = true;
  String? _lastPaymentId;
  Map<String, dynamic>? _reading;
  String? _loadError;

  static const bool debugUseStoreIap = true;

  TarotSpreadType get _effectiveSpreadType => widget.spreadType ?? TarotSpreadType.three;

  double get _amount {
    switch (_effectiveSpreadType) {
      case TarotSpreadType.three:
        return 149.0;
      case TarotSpreadType.six:
        return 199.0;
      case TarotSpreadType.twelve:
        return 250.0;
    }
  }

  String get _sku {
    switch (_effectiveSpreadType) {
      case TarotSpreadType.three:
        return ProductCatalog.tarot3_149;
      case TarotSpreadType.six:
        return ProductCatalog.tarot6_199;
      case TarotSpreadType.twelve:
        return ProductCatalog.tarot12_250;
    }
  }

  String get _packageTitle {
    switch (_effectiveSpreadType) {
      case TarotSpreadType.three:
        return "Hızlı Açılım (3 Kart)";
      case TarotSpreadType.six:
        return "Derin Açılım (6 Kart)";
      case TarotSpreadType.twelve:
        return "Premium Açılım (12 Kart)";
    }
  }

  String get _packageSubtitle {
    switch (_effectiveSpreadType) {
      case TarotSpreadType.three:
        return "Geçmiş–Şimdi–Yakın Gelecek ekseninde net bir okuma.";
      case TarotSpreadType.six:
        return "İlişki/iş/para odağında daha katmanlı yorum ve öneriler.";
      case TarotSpreadType.twelve:
        return "Kapsamlı tema analizi, ek mesajlar ve güçlü kapanış.";
    }
  }

  @override
  void initState() {
    super.initState();
    _loadReading();
  }

  bool _asBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = (v ?? '').toString().toLowerCase().trim();
    return s == 'true' || s == '1' || s == 'yes';
  }

  TarotSpreadType _spreadFromRaw(dynamic raw) {
    final s = (raw ?? '').toString().toLowerCase().trim();
    if (s == 'six') return TarotSpreadType.six;
    if (s == 'twelve') return TarotSpreadType.twelve;
    return TarotSpreadType.three;
  }

  bool _isReadyLockedOrDone(Map<String, dynamic>? d) {
    if (d == null) return false;
    if (_asBool(d['has_result'])) return true;
    final s = (d['status'] ?? '').toString().toLowerCase().trim();
    return s == 'completed' || s == 'done' || s == 'ready_locked' || s == 'ready_unlocked';
  }

  // ✅ Backend formatı: ["major_18_moon|R", "major_00_fool|U", ...]
  List<String> _cardsForApi() {
    return widget.selectedCards.map((c) {
      final suffix = c.isReversed ? 'R' : 'U';
      return '${c.id}|$suffix';
    }).toList();
  }

  Future<void> _loadReading() async {
    setState(() {
      _loadingReading = true;
      _loadError = null;
    });
    try {
      final deviceId = await DeviceIdService.getOrCreate();
      final d = await TarotApi.detail(readingId: widget.readingId, deviceId: deviceId);
      if (!mounted) return;
      setState(() => _reading = d);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = '$e');
    } finally {
      if (mounted) setState(() => _loadingReading = false);
    }
  }

  Future<void> _openResultAfterUnlock({required String deviceId}) async {
    Map<String, dynamic> d = await TarotApi.detail(readingId: widget.readingId, deviceId: deviceId);
    for (var i = 0; i < 8; i++) {
      final txt = (d['result_text'] ?? '').toString().trim();
      if (txt.isNotEmpty) break;
      await Future.delayed(Duration(milliseconds: 500 + (i * 250)));
      d = await TarotApi.detail(readingId: widget.readingId, deviceId: deviceId);
    }
    final resultText = (d['result_text'] ?? '').toString().trim();
    if (resultText.isEmpty) {
      throw Exception('Yorum metni henüz açılamadı. Lütfen tekrar dene.');
    }

    final question = (widget.question ?? '').trim().isNotEmpty
        ? widget.question!.trim()
        : (d['question'] ?? 'Tarot').toString();
    final spreadType = widget.spreadType ?? _spreadFromRaw(d['spread_type']);
    final selectedCards = widget.selectedCards.isNotEmpty
        ? widget.selectedCards
        : TarotDeck.cardsFromApiList((d['selected_cards'] is List) ? (d['selected_cards'] as List) : const []);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TarotResultScreen(
          question: question,
          spreadType: spreadType,
          selectedCards: selectedCards,
          resultText: resultText,
        ),
      ),
    );
  }

  Future<void> _payStoreIap() async {
    final deviceId = await DeviceIdService.getOrCreate();

    // Seçim ekranından gelindiyse kartları yeniden güvenceye al.
    final cards = _cardsForApi();
    if (cards.isNotEmpty) {
      await TarotApi.selectCards(
        readingId: widget.readingId,
        cards: cards,
        deviceId: deviceId,
      );
    }

    final verify = await IapService.instance.buyAndVerify(
      readingId: widget.readingId,
      sku: _sku,
    );

    if (!verify.verified) {
      throw Exception("Ödeme doğrulanamadı: ${verify.status}");
    }

    if (mounted) setState(() => _lastPaymentId = verify.paymentId);
    await _openResultAfterUnlock(deviceId: deviceId);
  }

  Future<void> _payAndContinue() async {
    if (_loading) return;
    final text = ((_reading?['result_text'] ?? '').toString()).trim();
    final readyByStatus = _isReadyLockedOrDone(_reading);
    if (text.isEmpty && !readyByStatus) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yorumun henüz hazır değil. Birkaç dakika içinde Profil > Benim Okumalarım’dan tekrar deneyebilirsin.')),
      );
      return;
    }

    setState(() {
      _loading = true;
    });
    try {
      if (kReleaseMode) {
        await _payStoreIap();
      } else {
        if (debugUseStoreIap) {
          await _payStoreIap();
        } else {
          final devId = await DeviceIdService.getOrCreate();
          final cards = _cardsForApi();
          if (cards.isNotEmpty) {
            await TarotApi.selectCards(
              readingId: widget.readingId,
              cards: cards,
              deviceId: devId,
            );
          }
          await TarotApi.markPaid(
            readingId: widget.readingId,
            paymentRef: 'TEST-DEBUG',
            deviceId: devId,
          );
          await _openResultAfterUnlock(deviceId: devId);
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ödeme hatası: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MysticScaffold(
      scrimOpacity: 0.84,
      patternOpacity: 0.16,
      appBar: AppBar(title: const Text('Ödeme')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _packageTitle,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _packageSubtitle,
                          style: TextStyle(color: Colors.white.withOpacity(0.85), height: 1.25),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Bu paket şunları içerir:",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.92),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "• Kart seçimi ve pozisyonlara göre yorum\n"
                          "• Soruna özel kapsamlı analiz\n"
                          "• Sonuç ekranı + kısa değerlendirme",
                          style: TextStyle(color: Colors.white.withOpacity(0.85), height: 1.25),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Tutar: ${_amount.toStringAsFixed(0)} ₺",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "+ vergiler",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.78),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Vergiler Google Play tarafından ödeme sırasında eklenir.",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.70),
                            fontSize: 12,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (!kReleaseMode)
                          Text(
                            "SKU: $_sku",
                            style: TextStyle(color: Colors.white.withOpacity(0.70), fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_lastPaymentId != null)
                    Text(
                      'Son işlem: $_lastPaymentId',
                      style: TextStyle(color: Colors.white.withOpacity(0.75)),
                    ),
                  const SizedBox(height: 10),
                  if (_loadingReading)
                    Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Yorum durumu kontrol ediliyor...',
                          style: TextStyle(color: Colors.white.withOpacity(0.82), fontSize: 12),
                        ),
                      ],
                    )
                  else if (_loadError != null)
                    Text(
                      'Durum alınamadı: $_loadError',
                      style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12),
                    )
                  else if (((_reading?['result_text'] ?? '').toString().trim().isEmpty) && !_isReadyLockedOrDone(_reading))
                    Text(
                      'Yorumun henüz tamamen hazır değil. Hazır olduğunda bu ekrandan kilidi açabilirsin.',
                      style: TextStyle(color: Colors.white.withOpacity(0.90), fontSize: 13),
                    )
                  else ...[
                    const Text(
                      'Yorumun hazır 🎉',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ödemeyi tamamlayınca tarot yorumunun tamamı açılır.',
                      style: TextStyle(color: Colors.white.withOpacity(0.86), fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            GradientButton(
              text: _loading ? 'Ödeme işleniyor...' : 'Ödemeyi Başlat ve Yorumu Gör',
              onPressed: (_loading || _loadingReading) ? null : _payAndContinue,
            ),
            const SizedBox(height: 10),
            Text(
              'Yorum önce hazırlanır, ödeme sonrası kilit açılır.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.70), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
