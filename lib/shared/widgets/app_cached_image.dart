import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class AppCachedImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final ImageRepeat repeat;
  final double fadeInDurationMs;
  final double fadeOutDurationMs;
  final String? cacheKey;
  final WidgetBuilder? placeholder;
  final WidgetBuilder? errorWidget;
  final BorderRadius? borderRadius;
  final Color? placeholderColor;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final int? maxWidthDiskCache;
  final int? maxHeightDiskCache;

  const AppCachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.fadeInDurationMs = 200,
    this.fadeOutDurationMs = 120,
    this.cacheKey,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
    this.placeholderColor,
    this.memCacheWidth,
    this.memCacheHeight,
    this.maxWidthDiskCache,
    this.maxHeightDiskCache,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectivePlaceholderBg = placeholderColor ?? const Color(0xFF141721);

    Widget buildPlaceholder(BuildContext c) {
      if (placeholder != null) return placeholder!(c);
      return _ShimmerBox(
        width: width,
        height: height,
        baseColor: effectivePlaceholderBg,
        highlightColor: const Color(0xFF222738),
      );
    }

    Widget buildError(BuildContext c, String? url, Object? err) {
      if (errorWidget != null) return errorWidget!(c);
      return Container(
        width: width,
        height: height,
        color: effectivePlaceholderBg,
        alignment: Alignment.center,
        child: Icon(
          Icons.broken_image_outlined,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
          size: 26,
        ),
      );
    }

    final effectiveUrl = imageUrl?.trim();
    final hasUrl = effectiveUrl != null && effectiveUrl.isNotEmpty;

    Widget child;
    if (!hasUrl) {
      child = buildError(context, null, 'empty url');
    } else {
      final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
      final effectiveMemWidth = memCacheWidth ??
          (width != null ? (width! * dpr).ceil() : 400);
      final effectiveMemHeight = memCacheHeight ??
          (height != null ? (height! * dpr).ceil() : 600);
      final effectiveDiskWidth = maxWidthDiskCache ?? 800;
      final effectiveDiskHeight = maxHeightDiskCache ?? 1200;

      child = CachedNetworkImage(
        imageUrl: effectiveUrl,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        repeat: repeat,
        cacheKey: cacheKey ?? effectiveUrl,
        fadeInDuration: Duration(milliseconds: fadeInDurationMs.round()),
        fadeOutDuration: Duration(milliseconds: fadeOutDurationMs.round()),
        memCacheWidth: effectiveMemWidth,
        memCacheHeight: effectiveMemHeight,
        maxWidthDiskCache: effectiveDiskWidth,
        maxHeightDiskCache: effectiveDiskHeight,
        placeholder: (c, _) => buildPlaceholder(c),
        errorWidget: buildError,
      );
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: child,
      );
    }
    return child;
  }
}

class _ShimmerBox extends StatefulWidget {
  const _ShimmerBox({
    this.width,
    this.height,
    this.baseColor,
    this.highlightColor,
  });

  final double? width;
  final double? height;
  final Color? baseColor;
  final Color? highlightColor;

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.baseColor ?? const Color(0xFF141721);
    final highlight = widget.highlightColor ?? const Color(0xFF222738);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1.5 + _ctrl.value * 3.0, -0.3),
              end: Alignment(-0.5 + _ctrl.value * 3.0, 0.3),
              colors: [base, highlight, base],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}
