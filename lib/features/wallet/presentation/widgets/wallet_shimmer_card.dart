import 'package:flutter/material.dart';

/// A sleek, continuous shimmering effect container designed for dark luxury theme.
class ShimmerContainer extends StatefulWidget {
  const ShimmerContainer({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 16,
    this.baseColor = const Color(0xff16151d),
    this.highlightColor = const Color(0xff292736),
    this.child,
  });

  final double? width;
  final double? height;
  final double borderRadius;
  final Color baseColor;
  final Color highlightColor;
  final Widget? child;

  @override
  State<ShimmerContainer> createState() => _ShimmerContainerState();
}

class _ShimmerContainerState extends State<ShimmerContainer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
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
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.06),
              width: 1.0,
            ),
            gradient: LinearGradient(
              begin: Alignment(-2.0 + _ctrl.value * 4.0, -0.4),
              end: Alignment(-0.5 + _ctrl.value * 4.0, 0.4),
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: widget.child,
        );
      },
      child: widget.child,
    );
  }
}

/// Shimmer placeholder specifically tailored for VIP Subscription Plans
class VipPlanShimmerCard extends StatelessWidget {
  const VipPlanShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerContainer(
      height: 148,
      width: double.infinity,
      borderRadius: 18,
      baseColor: const Color(0xff14131a),
      highlightColor: const Color(0xff272433),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 16,
                        width: 160,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 11,
                        width: 100,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      height: 22,
                      width: 70,
                      decoration: BoxDecoration(
                        color: const Color(0xffffb800).withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 16,
                      width: 55,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.06),
            ),
            Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  Expanded(
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  if (i != 2) const SizedBox(width: 10),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer placeholder specifically tailored for Coins Recharge Packages
class CoinPackageShimmerCard extends StatelessWidget {
  const CoinPackageShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerContainer(
      borderRadius: 18,
      baseColor: const Color(0xff14131a),
      highlightColor: const Color(0xff262432),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Spacer(),
            // Shimmer circle for coin
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xfff59e0b).withValues(alpha: 0.18),
              ),
            ),
            const SizedBox(height: 10),
            // Shimmer bar for coin amount
            Container(
              height: 18,
              width: 58,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 5),
            // Shimmer bar for "coins" text
            Container(
              height: 10,
              width: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const Spacer(),
            // Shimmer button for price
            Container(
              height: 38,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xffff2d79).withValues(alpha: 0.16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
