import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../widgets/feature_card.dart';
import '../../widgets/guide_overlay.dart';
import '../../widgets/mystic_scaffold.dart';
import '../../models/profile_models.dart';

import '../coffee/coffee_screen.dart';
import '../hand/hand_screen.dart';
import '../tarot/tarot_intro_screen.dart';
import '../numerology/numerology_intro_screen.dart';
import '../birthchart/birthchart_intro_screen.dart';
import '../personality/personality_intro_screen.dart';
import '../synastry/synastry_intro_screen.dart';

import '../iap/iap_debug_screen.dart';
import '../profile/profile_screen.dart';
import '../../services/device_id_service.dart';
import '../../services/notification_service.dart';
import '../../services/profile_api.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  bool _statusLoading = false;
  int _pendingCount = 0;
  int _readyLockedCount = 0;
  String? _statusError;

  bool _isReadyLockedOrDone(ProfileReadingItem r) {
    final s = r.status.toLowerCase().trim();
    return s == 'completed' || s == 'done' || s == 'ready_locked' || s == 'ready_unlocked';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowNotificationPrompt());
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReadingStatus());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadReadingStatus();
    }
  }

  Future<void> _loadReadingStatus() async {
    if (!mounted) return;
    setState(() {
      _statusLoading = true;
      _statusError = null;
    });
    try {
      final deviceId = await DeviceIdService.getOrCreate();
      final res = await ProfileApi.getHistory(deviceId: deviceId, limit: 20);
      int pending = 0;
      int readyLocked = 0;
      for (final ProfileReadingItem r in res.items) {
        final hasResult = r.hasResult || (r.resultText ?? '').trim().isNotEmpty || _isReadyLockedOrDone(r);
        if (!hasResult) {
          pending++;
          continue;
        }
        if (!r.isPaid) {
          readyLocked++;
        }
      }
      if (!mounted) return;
      setState(() {
        _pendingCount = pending;
        _readyLockedCount = readyLocked;
        _statusLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusError = e.toString();
        _statusLoading = false;
      });
    }
  }

  Future<void> _maybeShowNotificationPrompt() async {
    if (!mounted) return;
    final shouldShow = await NotificationService.shouldShowNotificationPrompt();
    if (!shouldShow || !mounted) return;
    final context = this.context;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1C2E),
        title: Text(
          'Bildirimler',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Bildirimleri açarak yorumunuz hazır olduğunda ve günlük hatırlatmalar alabilirsiniz. LunAura\'yı günlük kullanmanız için sizi yönlendireceğiz.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () {
              NotificationService.markPromptShown();
              Navigator.of(ctx).pop();
            },
            child: Text('Şimdi değil', style: TextStyle(color: AppColors.textSecondary)),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await NotificationService.requestPermissionAndRegister();
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.gold),
            child: const Text('Aç'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fadeController.dispose();
    super.dispose();
  }

  void _openCoffee(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CoffeeScreen()));
  }

  void _openHand(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HandScreen()));
  }

  void _openTarot(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TarotIntroScreen()));
  }

  void _openNumerology(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NumerologyIntroScreen()));
  }

  void _openBirthChart(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BirthChartIntroScreen()));
  }

  void _openPersonality(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PersonalityIntroScreen()));
  }

  void _openSynastry(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SynastryIntroScreen()));
  }

  void _openIapDebug(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const IapDebugScreen()));
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
  }

  Widget _readingStatusCard(BuildContext context) {
    if (_statusLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Yorum durumun kontrol ediliyor...',
                style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    if (_statusError != null || (_pendingCount == 0 && _readyLockedCount == 0)) {
      return const SizedBox.shrink();
    }

    String line;
    if (_pendingCount > 0 && _readyLockedCount > 0) {
      line = '$_pendingCount yorum hazırlanıyor · $_readyLockedCount yorum hazır (kilitli)';
    } else if (_pendingCount > 0) {
      line = '$_pendingCount yorum hazırlanıyor';
    } else {
      line = '$_readyLockedCount yorum hazır (kilitli)';
    }

    return InkWell(
      onTap: () => _openProfile(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF2A1B38).withOpacity(0.82),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF5C361).withOpacity(0.45)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.notifications_active_outlined, color: Color(0xFFF5C361)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Okuma Durumu',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$line. Detaylar için Benim Okumalarım\'a dokun.',
                    style: TextStyle(color: Colors.white.withOpacity(0.82), fontSize: 12, height: 1.3),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }

  void _openGuide(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => GuideOverlay(
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MysticScaffold(
      scrimOpacity: 0.62,
      patternOpacity: 0.22,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) => LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFFFFE5A0),
                        AppColors.gold,
                        AppColors.goldSoft,
                      ],
                    ).createShader(bounds),
                    child: const Text(
                      'LunAura',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.aiAccent.withOpacity(0.35),
                          AppColors.aiAccentSoft.withOpacity(0.25),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.aiAccent.withOpacity(0.6),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, size: 14, color: AppColors.aiAccent),
                        const SizedBox(width: 5),
                        Text(
                          'AI destekli kişisel rehberin',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.aiAccent,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kaderin, senin için hazır.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                                Text(
                                  '7+ analiz türü · Kişiselleştirilmiş AI yorumları · PDF rapor',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary.withOpacity(0.85),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _openGuide(context),
                            icon: Icon(
                              Icons.auto_awesome,
                              color: AppColors.aiAccent,
                              size: 28,
                            ),
                            tooltip: 'AI Rehber',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: FadeTransition(
                opacity: _fadeAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListView(
                    children: [
                      _readingStatusCard(context),
                      if (!_statusLoading && _statusError == null && (_pendingCount > 0 || _readyLockedCount > 0))
                        const SizedBox(height: 12),
                      if (!kReleaseMode) ...[
                        FeatureCard(
                          title: 'IAP Debug',
                          subtitle: 'Ürünleri gör, satın alma/verify test et (debug only).',
                          icon: Icons.bug_report_outlined,
                          onTap: () => _openIapDebug(context),
                          showAiBadge: false,
                        ),
                        const SizedBox(height: 12),
                      ],

                      FeatureCard(
                      title: 'Kahve Falı',
                      subtitle: 'Fotoğraf yükle, detaylı fal yorumunu al.',
                      icon: Icons.coffee_outlined,
                      onTap: () => _openCoffee(context),
                    ),
                    const SizedBox(height: 12),

                    FeatureCard(
                      title: 'El Falı',
                      subtitle: 'Avuç içi analizi ve kişilik haritası.',
                      icon: Icons.pan_tool_outlined,
                      onTap: () => _openHand(context),
                    ),
                    const SizedBox(height: 12),

                    FeatureCard(
                      title: 'Tarot',
                      subtitle: '3 - 6 - 12 kart açılımları.',
                      icon: Icons.style_outlined,
                      onTap: () => _openTarot(context),
                    ),
                    const SizedBox(height: 12),

                    FeatureCard(
                      title: 'Numeroloji',
                      subtitle: 'Yaşam sayısı, kader sayısı ve daha fazlası.',
                      icon: Icons.auto_awesome_outlined,
                      onTap: () => _openNumerology(context),
                    ),
                    const SizedBox(height: 12),

                    FeatureCard(
                      title: 'Doğum Haritası',
                      subtitle: 'Doğum tarihi, yer ve (opsiyonel) saat ile analiz.',
                      icon: Icons.public_outlined,
                      onTap: () => _openBirthChart(context),
                    ),
                    const SizedBox(height: 12),

                    FeatureCard(
                      title: 'Kişilik Analizi',
                      subtitle: 'Numeroloji + Doğum Haritası birleşik rapor + PDF indir.',
                      icon: Icons.psychology_alt_outlined,
                      onTap: () => _openPersonality(context),
                    ),
                    const SizedBox(height: 12),

                    FeatureCard(
                      title: 'Sinastri (Aşk Uyumu)',
                      subtitle: 'İki kişinin doğum bilgileriyle uyum analizi + PDF rapor.',
                      icon: Icons.favorite_outline,
                      onTap: () => _openSynastry(context),
                    ),
                  ],
                ),
                ),
              ),
            ),

            // ✅ Yeni bottom bar (Home + Profil)
            _BottomBar(
              onTapHome: () {}, // zaten home'dasın
              onTapProfile: () => _openProfile(context),
              active: _BottomTab.home,
            ),
          ],
        ),
      ),
        ],
      ),
    );
  }
}

enum _BottomTab { home, profile }

class _BottomBar extends StatelessWidget {
  final VoidCallback onTapHome;
  final VoidCallback onTapProfile;
  final _BottomTab active;

  const _BottomBar({
    required this.onTapHome,
    required this.onTapProfile,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.42),
        border: const Border(
          top: BorderSide(color: Colors.white12, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _BottomItem(
            icon: Icons.home_outlined,
            label: 'Ana Sayfa',
            active: active == _BottomTab.home,
            onTap: onTapHome,
          ),
          _BottomItem(
            icon: Icons.person_outline,
            label: 'Profil',
            active: active == _BottomTab.profile,
            onTap: onTapProfile,
          ),
        ],
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _BottomItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFFF5C361) : Colors.white70;
    final textColor = active ? const Color(0xFFF5C361) : Colors.white.withOpacity(0.70);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
