import 'package:flutter/material.dart';

class ProfileMenuTile extends StatelessWidget {
  const ProfileMenuTile({
    super.key,
    required this.title,
    required this.iconAsset,
    this.showDot = false,
    this.badgeText,
    required this.onTap,
  });

  final String title;
  final String iconAsset;
  final bool showDot;
  final String? badgeText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 58,
          child: ListTile(
            onTap: onTap,
            contentPadding: const EdgeInsets.symmetric(horizontal: 0),
            minLeadingWidth: 28,
            leading: Stack(
              clipBehavior: Clip.none,
              children: [
                Image.asset(iconAsset, width: 26, height: 26, filterQuality: FilterQuality.low),
                if (showDot)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: const Color(0xffef233c),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: const Color(0xff050505), width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              title,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (badgeText != null && badgeText!.isNotEmpty) ...[
                  _PulsingRewardBadge(badgeText: badgeText!),
                  const SizedBox(width: 6),
                ],
                Icon(Icons.chevron_left_rounded, color: Colors.white.withValues(alpha: 0.35)),
              ],
            ),
          ),
        ),
        Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
      ],
    );
  }
}

class _PulsingRewardBadge extends StatefulWidget {
  const _PulsingRewardBadge({required this.badgeText});
  final String badgeText;

  @override
  State<_PulsingRewardBadge> createState() => _PulsingRewardBadgeState();
}

class _PulsingRewardBadgeState extends State<_PulsingRewardBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.93, end: 1.07).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutSine,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xffff416c),
              Color(0xffff4b2b),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xffff416c).withValues(alpha: 0.45),
              blurRadius: 8,
              spreadRadius: 0.5,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          widget.badgeText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}
