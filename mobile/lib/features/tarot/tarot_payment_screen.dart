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
import 'tarot_processing_screen.dart';

class TarotPaymentScreen extends StatefulWidget {
  final String readingId;
  final String question;
  final TarotSpreadType spreadType;
  final List<TarotCard> selectedCards;

  const TarotPaymentScreen({
    super.key,
    required this.readingId,
    required this.question,
    required this.spreadType,
    required this.selectedCards,
  });

  @override
  State<TarotPaymentScreen> createState() => _TarotPaymentScreenState();
}

class _TarotPaymentScreenState extends State<TarotPaymentScreen> {
  bool _loading = false;
  String? _lastPaymentId;
  String _phase = 'idle';

  static const bool debugUseStoreIap = true;

  double get _amount {
    switch (widget.spreadType) {
      case TarotSpreadType.three:
        return 149.0;
      case TarotSpreadType.six:
        return 199.0;
      case TarotSpreadType.twelve:
        return 250.0;
    }
  }

  String get _sku {
    switch (widget.spreadType) {
      case TarotSpreadType.three:
        return ProductCatalog.tarot3_149;
      case TarotSpreadType.six:
        return ProductCatalog.tarot6_199;
      case TarotSpreadType.twelve:
        return ProductCatalog.tarot12_250;
    }
  }

  String get _packageTitle {
    switch (widget.spreadType) {
      case TarotSpreadType.three:
        return "Hızlı Açılım (3 Kart)";
      case TarotSpreadType.six:
        return "Derin Açılım (6 Kart)";
      case TarotSpreadType.twelve:
        return "Premium Açılım (12 Kart)";
    }
  }

  String get _packageSubtitle {
    switch (widget.spreadType) {
      case TarotSpreadType.three:
        return "Geçmiş–Şimdi–Yakın Gelecek ekseninde net bir okuma.";
      case TarotSpreadType.six:
        return "İlişki/iş/para odağında daha katmanlı yorum ve öneriler.";
      case TarotSpreadType.twelve:
        return "Kapsamlı tema analizi, ek mesajlar ve güçlü kapanış.";
    }
  }

  // ✅ Backend formatı: ["major_18_moon|R", "major_00_fool|U", ...]
  List<String> _cardsForApi() {
    return widget.selectedCards.map((c) {
      final suffix = c.isReversed ? 'R' : 'U';
      return '${c.id}|$suffix';
    }).toList();
  }

  void _fireGenerate() {
    DeviceIdService.getOrCreate().then((deviceId) {
      TarotApi.generate(readingId: widget.readingId, deviceId: deviceId).catchError((_) {});
    });
  }

  Future<void> _payStoreIap() async {
    final deviceId = await DeviceIdService.getOrCreate();

    // ✅ 0) KRİTİK GARANTİ:
    // ÖDEME BAŞLAMADAN ÖNCE seçilen kartlar DB’ye yazılsın.
    // /payments/verify tarot’ta “cards boş” edge-case’ini sıfırlar.
    await TarotApi.selectCards(
      readingId: widget.readingId,
      cards: _cardsForApi(),
      deviceId: deviceId,
    );

    final verify = await IapService.instance.buyAndVerify(
      readingId: widget.readingId,
      sku: _sku,
    );

    if (!verify.verified) {
      throw Exception("Ödeme doğrulanamadı: ${verify.status}");
    }

    if (mounted) setState(() => _lastPaymentId = verify.paymentId);

    _fireGenerate();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => TarotProcessingScreen(
          readingId: widget.readingId,
          question: widget.question,
          spreadType: widget.spreadType,
          selectedCards: widget.selectedCards,
        ),
      ),
      (route) => false,
    );
  }

  Future<void> _payAndContinue() async {
    setState(() {
      _loading = true;
      _phase = 'paying';
    });
    try {
      if (kReleaseMode) {
        await _payStoreIap();
      } else {
        if (debugUseStoreIap) {
          await _payStoreIap();
        } else {
          // Debug'da store kullanmıyorsan processing’e geç (generate’i processing tetikler)
          final devId = await DeviceIdService.getOrCreate();
          await TarotApi.selectCards(
            readingId: widget.readingId,
            cards: _cardsForApi(),
            deviceId: devId,
          );
          _fireGenerate();
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => TarotProcessingScreen(
                readingId: widget.readingId,
                question: widget.question,
                spreadType: widget.spreadType,
                selectedCards: widget.selectedCards,
              ),
            ),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ödeme/Yorum hatası: $e')),
      );
    } finally {
      if (mounted) setState(() {
        _loading = false;
        _phase = 'idle';
      });
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
                ],
              ),
            ),
            if (_phase == 'preparing')
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Yorumunuz hazırlanıyor, lütfen bekleyin...',
                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 12),
            GradientButton(
              text: _loading
                  ? (_phase == 'preparing' ? 'Yorumunuz hazırlanıyor...' : 'Ödeme işleniyor...')
                  : 'Ödemeyi Başlat ve Yorumu Gör',
              onPressed: _loading ? null : _payAndContinue,
            ),
            const SizedBox(height: 10),
            Text(
              'Ödeme sonrası yorum hazırlanır ve sonuç ekranına otomatik yönlendirilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.70), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
