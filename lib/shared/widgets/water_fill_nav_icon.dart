import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A navigation icon that animates a liquid / water filling effect
/// from bottom to top with a smooth, vivid fire gradient when active or tapped.
class WaterFillNavIcon extends StatefulWidget {
  final String unselectedAssetPath;
  final String selectedAssetPath;
  final double size;
  final Duration duration;
  final Gradient? gradient;

  const WaterFillNavIcon({
    super.key,
    required this.unselectedAssetPath,
    required this.selectedAssetPath,
    this.size = 28,
    this.duration = const Duration(milliseconds: 1350),
    this.gradient,
  });

  /// Vivid, clearly visible fire flame gradient (red -> flame orange -> warm gold)
  static const defaultFireGradient = LinearGradient(
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    colors: [
      Color(0xFFE50914), // Deep vibrant fire red
      Color(0xFFFF5722), // Blazing flame orange-red
      Color(0xFFFF9100), // Glowing fire orange
      Color(0xFFFFD600), // Radiant flame gold
    ],
    stops: [0.0, 0.38, 0.72, 1.0],
  );

  @override
  State<WaterFillNavIcon> createState() => _WaterFillNavIconState();
}

class _WaterFillNavIconState extends State<WaterFillNavIcon>
    with SingleTickerProviderStateMixin {
  static final Set<Object> _completedKeys = <Object>{};
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    final cacheKey = widget.key ?? widget.selectedAssetPath;
    final alreadyCompleted = _completedKeys.contains(cacheKey);

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: alreadyCompleted ? 1.0 : 0.0,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );

    if (!alreadyCompleted) {
      _controller.forward(from: 0.0).then((_) {
        if (mounted) {
          _completedKeys.add(cacheKey);
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gradient = widget.gradient ?? WaterFillNavIcon.defaultFireGradient;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final progress = _animation.value;

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Base icon turns to crisp solid white on tap
              Image.asset(
                widget.selectedAssetPath,
                width: widget.size,
                height: widget.size,
                color: Colors.white,
                colorBlendMode: BlendMode.srcIn,
                filterQuality: FilterQuality.low,
              ),
              // 2. Rising water-fill fiery gradient layer filling up over the white icon
              ClipPath(
                clipper: _WaterWaveClipper(progress),
                child: ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) => gradient.createShader(bounds),
                  child: Image.asset(
                    widget.selectedAssetPath,
                    width: widget.size,
                    height: widget.size,
                    filterQuality: FilterQuality.low,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WaterWaveClipper extends CustomClipper<Path> {
  final double progress;

  _WaterWaveClipper(this.progress);

  @override
  Path getClip(Size size) {
    final path = Path();
    if (progress <= 0.0) {
      return path;
    }
    if (progress >= 1.0) {
      path.addRect(Rect.fromLTWH(0, 0, size.width, size.height));
      return path;
    }

    // Water height level from the bottom (progress = 1 is levelY = 0)
    final levelY = size.height * (1.0 - progress);

    // Smooth wave amplitude peaking mid-fill and fading out at completion
    final waveAmplitude = 1.6 * math.sin(progress * math.pi);
    final phase = progress * 4.0 * math.pi;

    path.moveTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, levelY);

    const segments = 24;
    final step = size.width / segments;
    for (int i = segments; i >= 0; i--) {
      final x = i * step;
      final y = levelY +
          waveAmplitude * math.sin((x / size.width * 2 * math.pi) + phase);
      path.lineTo(x, y.clamp(0.0, size.height));
    }

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _WaterWaveClipper oldClipper) {
    return oldClipper.progress != progress;
  }
}
