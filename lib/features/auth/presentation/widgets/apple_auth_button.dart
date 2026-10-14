import 'package:flutter/material.dart';

class AppleAuthButton extends StatelessWidget {
  const AppleAuthButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.loading = false,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: loading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFF1D1D1F), width: 1.2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading) ...[
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
            ),
          ] else ...[
            const AppleLogoIcon(size: 20),
          ],
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.05,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AppleLogoIcon extends StatelessWidget {
  const AppleLogoIcon({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size.square(size),
        painter: _AppleLogoPainter(),
      ),
    );
  }
}

class _AppleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    final path = Path()
      ..moveTo(cx + w * 0.22, cy - h * 0.22)
      ..cubicTo(
        cx + w * 0.22, cy - h * 0.30,
        cx + w * 0.14, cy - h * 0.38,
        cx + w * 0.04, cy - h * 0.40,
      )
      ..cubicTo(
        cx - w * 0.04, cy - h * 0.42,
        cx - w * 0.14, cy - h * 0.34,
        cx - w * 0.20, cy - h * 0.24,
      )
      ..cubicTo(
        cx - w * 0.28, cy - h * 0.12,
        cx - w * 0.36, cy + h * 0.06,
        cx - w * 0.22, cy + h * 0.24,
      )
      ..cubicTo(
        cx - w * 0.12, cy + h * 0.36,
        cx - w * 0.02, cy + h * 0.40,
        cx + w * 0.06, cy + h * 0.36,
      )
      ..cubicTo(
        cx + w * 0.14, cy + h * 0.32,
        cx + w * 0.22, cy + h * 0.26,
        cx + w * 0.30, cy + h * 0.30,
      )
      ..cubicTo(
        cx + w * 0.38, cy + h * 0.36,
        cx + w * 0.44, cy + h * 0.38,
        cx + w * 0.46, cy + h * 0.32,
      )
      ..cubicTo(
        cx + w * 0.48, cy + h * 0.26,
        cx + w * 0.44, cy + h * 0.22,
        cx + w * 0.40, cy + h * 0.20,
      )
      ..cubicTo(
        cx + w * 0.38, cy + h * 0.19,
        cx + w * 0.36, cy + h * 0.18,
        cx + w * 0.36, cy + h * 0.16,
      )
      ..cubicTo(
        cx + w * 0.37, cy + h * 0.02,
        cx + w * 0.28, cy - h * 0.08,
        cx + w * 0.22, cy - h * 0.22,
      )
      ..close();

    canvas.drawPath(path, paint);

    final leaf = Path()
      ..moveTo(cx + w * 0.05, cy - h * 0.40)
      ..cubicTo(
        cx + w * 0.09, cy - h * 0.46,
        cx + w * 0.22, cy - h * 0.48,
        cx + w * 0.28, cy - h * 0.38,
      )
      ..cubicTo(
        cx + w * 0.18, cy - h * 0.32,
        cx + w * 0.00, cy - h * 0.32,
        cx + w * 0.05, cy - h * 0.40,
      )
      ..close();

    canvas.drawPath(leaf, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
