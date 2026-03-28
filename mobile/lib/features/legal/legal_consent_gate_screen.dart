import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../services/legal_consent_service.dart';
import '../../widgets/mystic_scaffold.dart';
import '../landing/landing_screen.dart';

/// Uygulama açılışında gösterilir. Kullanıcı Sözleşmesi'ni onaylamamışsa bu ekran açılır;
/// onayladıktan sonra veri PostgreSQL'e kaydedilir ve ana ekrana geçilir.
class LegalConsentGateScreen extends StatefulWidget {
  const LegalConsentGateScreen({super.key});

  @override
  State<LegalConsentGateScreen> createState() => _LegalConsentGateScreenState();
}

class _LegalConsentGateScreenState extends State<LegalConsentGateScreen> {
  bool _loading = false;
  bool _checking = true;

  static const String _termsBody = """
Kullanıcı Sözleşmesi (Özet)

- Uygulama içerikleri ve analizler "rehberlik/eğlence" amaçlıdır; kesin hüküm değildir.
- Kullanıcı, uygulamayı yasalara uygun şekilde kullanmayı kabul eder.
- Dijital içerik/servis sunulduğu için satın alımlar Google Play kuralları kapsamındadır.
- Uygulama, hizmet kalitesini artırmak için akışları güncelleyebilir.

Tam metni aşağıdaki butondan PDF olarak açabilirsin.
""";

  @override
  void initState() {
    super.initState();
    _checkAlreadyAccepted();
  }

  Future<void> _checkAlreadyAccepted() async {
    final accepted = await LegalConsentService.hasUserAccepted();
    if (!mounted) return;
    setState(() => _checking = false);
    if (accepted) {
      _goToHome();
    }
  }

  void _goToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const WelcomeLandingScreen()),
    );
  }

  Future<void> _openPdf() async {
    const assetPath = 'assets/legal/lunaura_kullanici_sozlesmesi.pdf';
    const outFileName = 'lunaura_kullanici_sozlesmesi.pdf';

    try {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$outFileName');
      await file.writeAsBytes(bytes, flush: true);
      final result = await OpenFilex.open(file.path);
      if (mounted && result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF açılamadı: ${result.message ?? "Cihazda PDF görüntüleyici olmayabilir."}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF açılırken hata: $e')),
        );
      }
    }
  }

  Future<void> _onAccept() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final savedToServer = await LegalConsentService.accept();
      if (!mounted) return;
      _goToHome();
      if (mounted && !savedToServer) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Onay cihazda kaydedildi. Sunucuya ulaşılamadı; internet olduğunda tekrar deneyebilirsiniz.'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Onay kaydedilemedi. İnternet bağlantınızı kontrol edin: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: Color(0xFF1a0a1f),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFF5C361)),
        ),
      );
    }

    return MysticScaffold(
      scrimOpacity: 0.70,
      patternOpacity: 0.22,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text(
              'Kullanıcı Sözleşmesi',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFF5C361),
                    side: const BorderSide(color: Color(0xFFF5C361)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _openPdf,
                  icon: const Icon(Icons.picture_as_pdf, size: 22),
                  label: const Text('Tam Metni PDF Olarak Aç', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    _termsBody.trim(),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF5C361),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _loading ? null : _onAccept,
                  child: _loading
                      ? const SizedBox(
                          height: 26,
                          width: 26,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Text(
                          'Kabul Ediyorum',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
