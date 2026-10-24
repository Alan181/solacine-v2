import 'package:flutter/material.dart';
import '../../../../app/i18n.dart';

class RewardsCoinsAwardOverlay extends StatefulWidget {
  const RewardsCoinsAwardOverlay({super.key, required this.coins});

  final int coins;

  @override
  State<RewardsCoinsAwardOverlay> createState() => _RewardsCoinsAwardOverlayState();
}

class _RewardsCoinsAwardOverlayState extends State<RewardsCoinsAwardOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 480));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.70, end: 1.08), weight: 60),
      TweenSequenceItem(tween: Tween<double>(begin: 1.08, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    const cardWidth = 290.0;
    const cardHeight = cardWidth * (1148.0 / 860.0); // 387.16 dp

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Background tap to dismiss
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _dismiss,
              child: const SizedBox.expand(),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: SizedBox(
                  width: cardWidth,
                  height: cardHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      // 1. Background celebration graphic
                      Image.asset(
                        'assets/images/marketing_bg.webp',
                        width: cardWidth,
                        height: cardHeight,
                        fit: BoxFit.fill,
                        filterQuality: FilterQuality.medium,
                      ),

                      // 2. Center Orange Sunburst Area (Y: ~154 to ~264)
                      Positioned(
                        top: 154,
                        left: 20,
                        right: 20,
                        height: 110,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.35),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.toll_rounded,
                                    color: Color(0xfffef08a),
                                    size: 19,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '+${widget.coins}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                    height: 1.0,
                                    shadows: [
                                      Shadow(
                                        color: Color(0x66000000),
                                        offset: Offset(0, 2),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                t.t('wallet_coins').toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 3. Lower Cream-White Card Area (Y: ~280 to ~374)
                      Positioned(
                        top: 280,
                        left: 20,
                        right: 20,
                        height: 96,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  t.t('congratulations'),
                                  style: const TextStyle(
                                    color: Color(0xffea580c),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  t.t(
                                    'you_received_coins',
                                    params: {'count': widget.coins.toString()},
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xffea580c),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(
                              height: 32,
                              child: FilledButton(
                                onPressed: _dismiss,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xff09090b),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 26),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                                child: Text(t.t('ok')),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 4. Subtle Top-Right Close Button
                      Positioned(
                        top: 10,
                        right: 8,
                        child: GestureDetector(
                          onTap: _dismiss,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.20),
                              ),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
