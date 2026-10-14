import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Standard iOS style activity indicator used across the application.
class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({
    super.key,
    this.radius = 12.0,
    this.color = Colors.white,
  });

  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CupertinoActivityIndicator(
      radius: radius,
      color: color,
    );
  }
}
