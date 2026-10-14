import 'package:flutter/material.dart';

class ShinyGoldCoin extends StatelessWidget {
  const ShinyGoldCoin({
    super.key,
    this.size = 54,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Soft ambient warm gold bloom
          Container(
            width: size * 0.88,
            height: size * 0.88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xfff59e0b).withValues(alpha: 0.40),
                  blurRadius: size * 0.35,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          // Outer gold coin body
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xfffff2a8),
                  Color(0xfff59e0b),
                  Color(0xffd97706),
                  Color(0xff92400e),
                ],
                stops: [0.0, 0.45, 0.8, 1.0],
              ),
              border: Border.all(
                color: const Color(0xfffff8cc).withValues(alpha: 0.8),
                width: size * 0.04,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(size * 0.09),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    center: Alignment(-0.35, -0.4),
                    radius: 0.85,
                    colors: [
                      Color(0xfffffbeb),
                      Color(0xfffbbf24),
                      Color(0xffd97706),
                      Color(0xff78350f),
                    ],
                  ),
                  border: Border.all(
                    color: const Color(0xfffff8cc).withValues(alpha: 0.5),
                    width: size * 0.035,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.star_rounded,
                  size: size * 0.46,
                  color: const Color(0xfffffbeb),
                  shadows: [
                    Shadow(
                      color: const Color(0xff78350f).withValues(alpha: 0.85),
                      blurRadius: 3,
                      offset: const Offset(0, 1.2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Glint Sparkle 1 (Top-Left)
          Positioned(
            top: -size * 0.04,
            left: size * 0.04,
            child: Text(
              '✦',
              style: TextStyle(
                color: const Color(0xfffffbeb),
                fontSize: size * 0.26,
                height: 1.0,
                shadows: [
                  Shadow(
                    color: const Color(0xfffbbf24).withValues(alpha: 0.9),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
          // Glint Sparkle 2 (Bottom-Right)
          Positioned(
            bottom: -size * 0.02,
            right: size * 0.06,
            child: Text(
              '✦',
              style: TextStyle(
                color: const Color(0xfffffbeb),
                fontSize: size * 0.20,
                height: 1.0,
                shadows: [
                  Shadow(
                    color: const Color(0xfffbbf24).withValues(alpha: 0.9),
                    blurRadius: 5,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
