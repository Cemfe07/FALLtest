import 'package:flutter/material.dart';

import '../../services/tarot_api.dart';
import '../../widgets/mystic_loading_indicator.dart';
import '../../widgets/mystic_scaffold.dart';
import 'tarot_models.dart';
import 'tarot_select_screen.dart';

class TarotLoadingScreen extends StatefulWidget {
  final String question;
  final TarotSpreadType spreadType;

  const TarotLoadingScreen({
    super.key,
    required this.question,
    required this.spreadType,
  });

  @override
  State<TarotLoadingScreen> createState() => _TarotLoadingScreenState();
}

class _TarotLoadingScreenState extends State<TarotLoadingScreen> {
  @override
  void initState() {
    super.initState();
    _startAndGo();
  }

  String _spreadToApi(TarotSpreadType t) {
    switch (t) {
      case TarotSpreadType.three:
        return "three";
      case TarotSpreadType.six:
        return "six";
      case TarotSpreadType.twelve:
        return "twelve";
    }
  }

  Future<void> _startAndGo() async {
    try {
      final startRes = await TarotApi.start(
        topic: "Tarot",
        question: widget.question,
        name: "Misafir",
        age: null,
        spreadType: _spreadToApi(widget.spreadType),
      );

      final readingId = (startRes["id"] ?? "").toString();
      if (readingId.isEmpty) throw Exception("readingId boş döndü");

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TarotSelectScreen(
            readingId: readingId,
            question: widget.question,
            spreadType: widget.spreadType,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MysticScaffold(
      scrimOpacity: 0.78,
      patternOpacity: 0.16,
      appBar: AppBar(title: Text(widget.spreadType.title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MysticLoadingIndicator(
              message: 'AI yorumunuz hazırlanıyor…',
              submessage: 'Kartlarınız kişiselleştiriliyor',
              size: 110,
            ),
          ],
        ),
      ),
    );
  }
}
