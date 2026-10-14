import 'package:flutter/material.dart';
import 'package:dramereel_mobile/features/auth/presentation/widgets/google_auth_button.dart';
import 'package:dramereel_mobile/shared/widgets/app_cached_image.dart';

class ProfileUserHeaderCard extends StatelessWidget {
  const ProfileUserHeaderCard({
    super.key,
    required this.displayName,
    required this.idLabel,
    required this.emailLabel,
    required this.avatarUrl,
    required this.authProvider,
    required this.isVip,
    required this.onEdit,
  });

  final String displayName;
  final String idLabel;
  final String emailLabel;
  final String avatarUrl;
  final String authProvider;
  final bool isVip;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    Widget avatarContent(double radius) {
      final url = avatarUrl.trim();
      final isDefaultOrEmpty = url.isEmpty || url.contains('ui-avatars.com/api/');
      if (isDefaultOrEmpty) {
        return ClipOval(
          child: Image.asset(
            'assets/images/avatar.jpg',
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
          ),
        );
      }
      return ClipOval(
        child: SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: AppCachedImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (context) => ShimmerCircle(diameter: radius * 2),
            errorWidget: (context) => Image.asset(
              'assets/images/avatar.jpg',
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [
                          Color(0xffc084fc),
                          Color(0xfff43f5e),
                        ],
                      ).createShader(bounds),
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ),
                  if (authProvider.trim().isNotEmpty) ...[
                    const SizedBox(width: 8),
                    AuthProviderBadge(provider: authProvider),
                  ],
                ],
              ),
              if (idLabel.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  idLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (emailLabel.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  emailLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: onEdit,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (isVip)
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xfff58529),
                        Color(0xffdd2a7b),
                        Color(0xff8134af),
                        Color(0xff515bd4),
                      ],
                    ),
                  ),
                  child: avatarContent(21),
                )
              else
                avatarContent(22),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xff0b0b0b),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Icon(Icons.edit_rounded, size: 12, color: Colors.white.withValues(alpha: 0.85)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ShimmerCircle extends StatefulWidget {
  const ShimmerCircle({super.key, required this.diameter});

  final double diameter;

  @override
  State<ShimmerCircle> createState() => _ShimmerCircleState();
}

class _ShimmerCircleState extends State<ShimmerCircle> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Colors.white.withValues(alpha: 0.08);
    final hi = Colors.white.withValues(alpha: 0.22);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final v = _c.value;
        final a = (v - 0.35).clamp(0.0, 1.0);
        final b = v.clamp(0.0, 1.0);
        final c = (v + 0.35).clamp(0.0, 1.0);
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [base, hi, base],
              stops: [a, b, c],
            ).createShader(rect);
          },
          child: child,
        );
      },
      child: Container(
        width: widget.diameter,
        height: widget.diameter,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xff0b0b0b)),
      ),
    );
  }
}

class AuthProviderBadge extends StatelessWidget {
  const AuthProviderBadge({super.key, required this.provider});

  final String provider;

  @override
  Widget build(BuildContext context) {
    final p = provider.trim().toLowerCase();
    final Widget icon = switch (p) {
      'google' => const GoogleGIcon(size: 16),
      'apple' => Icon(Icons.apple, size: 16, color: Colors.white.withValues(alpha: 0.92)),
      'phone' => Icon(Icons.phone_rounded, size: 16, color: Colors.white.withValues(alpha: 0.92)),
      _ => Icon(Icons.email_outlined, size: 16, color: Colors.white.withValues(alpha: 0.92)),
    };
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      alignment: Alignment.center,
      child: icon,
    );
  }
}
