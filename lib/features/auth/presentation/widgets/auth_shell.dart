import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../localization/presentation/language_picker.dart';

class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.headerAssetPath,
    this.logoAssetPath,
    this.initialChildSize = 0.70,
    this.minChildSize = 0.70,
    this.maxChildSize = 0.92,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final String? headerAssetPath;
  final String? logoAssetPath;
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: const Color(0xff050505),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          /// Hero Image
          SizedBox(
            width: double.infinity,
            height: media.size.height * .55,
            child: _HeaderImage(assetPath: headerAssetPath),
          ),

          Positioned(
            top: media.padding.top + 12,
            right: 12,
            child: const LanguagePicker(),
          ),

          /// Bottom Sheet
          DraggableScrollableSheet(
            initialChildSize: initialChildSize,
            minChildSize: minChildSize,
            maxChildSize: maxChildSize,
            builder: (context, controller) {
              return ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(34),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 16,
                    sigmaY: 16,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xff111111).withValues(alpha: 0.92),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(34),
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 40,
                          offset: const Offset(0, -8),
                        )
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: SingleChildScrollView(
                        controller: controller,
                        padding: EdgeInsets.fromLTRB(
                          24,
                          16,
                          24,
                          media.viewInsets.bottom + 24,
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 45,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),

                            const SizedBox(height: 28),

                        if (logoAssetPath != null && logoAssetPath!.trim().isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.asset(
                              logoAssetPath!,
                              width: 76,
                              height: 76,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.low,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -.8,
                              ),
                            ),

                        if (subtitle.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            subtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 15,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 36),
                        ] else ...[
                          const SizedBox(height: 28),
                        ],

                            child,

                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HeaderImage extends StatefulWidget {
  const _HeaderImage({
    required this.assetPath,
  });

  final String? assetPath;

  @override
  State<_HeaderImage> createState() => _HeaderImageState();
}

class _HeaderImageState extends State<_HeaderImage> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    _anim = Tween<double>(begin: 0, end: 14).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.assetPath?.isNotEmpty == true
        ? widget.assetPath!
        : "assets/images/auth_hero.png";

    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: _anim,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, -_anim.value),
              child: child,
            );
          },
          child: Image.asset(
            path,
            fit: BoxFit.contain,
            alignment: Alignment.topCenter,
          ),
        ),

        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Color(0x22000000),
                Color(0x77000000),
                Color(0xFF050505),
              ],
              stops: [
                0,
                .45,
                .72,
                1,
              ],
            ),
          ),
        ),
      ],
    );
  }
}
