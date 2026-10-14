import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../app/i18n.dart';

class ProfileWalletRow extends StatelessWidget {
  const ProfileWalletRow({
    super.key,
    required this.coins,
    required this.onRecharge,
  });

  final int coins;
  final VoidCallback onRecharge;

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.t('wallet'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 17.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      '$coins',
                      style: const TextStyle(
                        color: Color(0xffffc107),
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Image.asset(
                      'assets/images/push_pro_icon.png',
                      width: 18,
                      height: 18,
                      filterQuality: FilterQuality.low,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      t.t('wallet_coins'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.60),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _AnimatedRechargeButton(
            onTap: onRecharge,
            label: t.t('recharge'),
          ),
        ],
      ),
    );
  }
}

class _AnimatedRechargeButton extends StatefulWidget {
  const _AnimatedRechargeButton({
    required this.onTap,
    required this.label,
  });

  final VoidCallback onTap;
  final String label;

  @override
  State<_AnimatedRechargeButton> createState() => _AnimatedRechargeButtonState();
}

class _AnimatedRechargeButtonState extends State<_AnimatedRechargeButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final progress = _ctrl.value;
        final glowOpacity = 0.28 + 0.16 * math.sin(progress * 2 * math.pi);

        return Container(
          height: 30, // Reduced height
          constraints: const BoxConstraints(minWidth: 92), // Wider button
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xffff2d79),
                Color(0xffff6b4a),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xffff2d79).withValues(alpha: glowOpacity),
                blurRadius: 10,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(999),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Animated light shine sweep beam
                    Positioned.fill(
                      child: Transform.translate(
                        offset: Offset(-90.0 + progress * 240.0, 0),
                        child: Transform.rotate(
                          angle: 0.35,
                          child: Container(
                            width: 28,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.0),
                                  Colors.white.withValues(alpha: 0.40),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Button text
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: Text(
                        widget.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold, // Bold text
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
