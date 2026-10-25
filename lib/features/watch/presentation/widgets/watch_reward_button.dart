import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:solacine_mobile/app/i18n.dart';

class WatchRewardButton extends StatefulWidget {
  const WatchRewardButton({
    super.key,
    required this.topPad,
    required this.rewardShakeAnimation,
    required this.rewardDismissed,
    required this.onTapReward,
    required this.onDismiss,
    required this.onRewardEarned,
    required this.isPlaying,
  });

  final double topPad;
  final Animation<double> rewardShakeAnimation;
  final bool rewardDismissed;
  final VoidCallback onTapReward;
  final VoidCallback onDismiss;
  final Future<void> Function() onRewardEarned;
  final bool isPlaying;

  @override
  State<WatchRewardButton> createState() => _WatchRewardButtonState();
}

class _WatchRewardButtonState extends State<WatchRewardButton> with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  bool _isClaiming = false;

  @override
  void initState() {
    super.initState();
    // Durasi putaran progress lingkaran = 1 menit (60 detik)
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    );

    // Timer tetap berjalan di background meskipun tombol di-dismiss (di-klik X)
    if (widget.isPlaying) {
      _progressController.repeat();
    }

    _progressController.addListener(() {
      if (_progressController.status == AnimationStatus.forward && _progressController.value >= 0.999) {
        _triggerReward();
      }
    });
  }

  @override
  void didUpdateWidget(covariant WatchRewardButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Otomatis pause/play animasi berdasarkan status video (isPlaying)
    if (widget.isPlaying) {
      if (!_progressController.isAnimating) {
        _progressController.forward();
      }
    } else {
      if (_progressController.isAnimating) {
        _progressController.stop();
      }
    }
  }

  Future<void> _triggerReward() async {
    if (_isClaiming) return;
    _isClaiming = true;

    try {
      await widget.onRewardEarned();
    } finally {
      if (mounted) {
        _isClaiming = false;
        // Reset animasi dari awal untuk siklus 1 menit berikutnya secara kontinu
        _progressController.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    const double buttonSize = 46.0;

    // STRUKTUR YANG BENAR:
    // 1. Positioned berada di luar (wajib di dalam Stack parent-nya agar tidak blank).
    // 2. Offstage berada di dalam Positioned untuk menyembunyikan tampilannya saja saat diklik X.
    return Positioned(
      top: widget.topPad + 86,
      left: 28,
      child: Offstage(
        offstage: widget.rewardDismissed,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                InkWell(
                  onTap: widget.onTapReward,
                  borderRadius: BorderRadius.circular(999),
                  child: AnimatedBuilder(
                    animation: widget.rewardShakeAnimation,
                    builder: (context, child) {
                      final s = math.sin(widget.rewardShakeAnimation.value * math.pi * 2);
                      return Transform.translate(
                        offset: Offset(s * 2.0, 0),
                        child: Transform.rotate(angle: s * 0.06, child: child),
                      );
                    },
                    child: SizedBox(
                      width: buttonSize + 6,
                      height: buttonSize + 6,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // GARIS PROGRES MELINGKAR DI PINGGIRAN BULATAN
                          SizedBox(
                            width: buttonSize + 4,
                            height: buttonSize + 4,
                            child: AnimatedBuilder(
                              animation: _progressController,
                              builder: (context, child) {
                                return CircularProgressIndicator(
                                  value: _progressController.value,
                                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                                  color: Colors.amber, // Warna garis progres
                                  strokeWidth: 2.5,    // Ketebalan garis di pinggir
                                );
                              },
                            ),
                          ),
                          // KONTEN UTAMA TOMBOL (BULATAN IKON)
                          Container(
                            width: buttonSize,
                            height: buttonSize,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                            ),
                            child: Center(
                              child: Image.asset(
                                'assets/images/app_gl_red_ic.png',
                                width: 24,
                                height: 24,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => const SizedBox(width: 24, height: 24),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // TOMBOL CLOSE (X) DI POJOK KANAN ATAS
                Positioned(
                  right: 0,
                  top: 0,
                  child: InkWell(
                    onTap: widget.onDismiss,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              t.t('reward'),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.90), fontWeight: FontWeight.w500, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
