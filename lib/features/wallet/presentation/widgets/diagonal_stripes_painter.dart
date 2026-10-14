import 'package:flutter/material.dart';

/// Draws subtle luxury diagonal stripes across cards as seen in VIP and Recharge designs.
class DiagonalStripesPainter extends CustomPainter {
  const DiagonalStripesPainter({
    this.stripeColor = const Color(0x08FFD700),
    this.stripeWidth = 0.9,
    this.spacing = 16.0,
    this.slope = 0.55,
  });

  final Color stripeColor;
  final double stripeWidth;
  final double spacing;
  final double slope;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final paint = Paint()
      ..color = stripeColor
      ..strokeWidth = stripeWidth
      ..style = PaintingStyle.stroke;

    final dx = size.height * slope;
    final minX = -dx;
    final maxX = size.width + dx;

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    for (double x = minX; x <= maxX; x += spacing) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + dx, 0),
        paint,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant DiagonalStripesPainter oldDelegate) {
    return oldDelegate.stripeColor != stripeColor ||
        oldDelegate.stripeWidth != stripeWidth ||
        oldDelegate.spacing != spacing ||
        oldDelegate.slope != slope;
  }
}
