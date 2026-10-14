import 'package:flutter/material.dart';

class WalletPaymentMethodTile extends StatelessWidget {
  const WalletPaymentMethodTile({
    super.key,
    required this.title,
    required this.subtitle,
    this.iconAsset,
    this.icon,
    this.badgeText,
    this.iconBgColor,
    this.iconWidget,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String? iconAsset;
  final IconData? icon;
  final String? badgeText;
  final Color? iconBgColor;
  final Widget? iconWidget;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          splashColor: Colors.white.withValues(alpha: 0.07),
          highlightColor: Colors.white.withValues(alpha: 0.04),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              // iOS secondary elevated dark surface
              color: const Color(0xff24252C),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 0.6,
              ),
            ),
            child: Row(
              children: [
                // Brand logo container with iOS rounded rect & subtle shadow
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: iconBgColor ?? Colors.white,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 0.6,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 4,
                        offset: const Offset(0, 1.5),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: iconWidget ??
                      (iconAsset != null
                          ? Padding(
                              padding: const EdgeInsets.all(7.5),
                              child: Image.asset(
                                iconAsset!,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.medium,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    icon ?? Icons.credit_card_rounded,
                                    color: Colors.black87,
                                    size: 22,
                                  );
                                },
                              ),
                            )
                          : Icon(
                              icon ?? Icons.credit_card_rounded,
                              color: Colors.black87,
                              size: 22,
                            )),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          if (badgeText != null && badgeText!.isNotEmpty) ...[
                            const SizedBox(width: 7),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6.5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                // iOS System Green tint
                                color: const Color(0xff34C759).withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xff34C759).withValues(alpha: 0.32),
                                  width: 0.6,
                                ),
                              ),
                              child: Text(
                                badgeText!,
                                style: const TextStyle(
                                  color: Color(0xff34C759),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2.5),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.52),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // iOS clean chevron
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.32),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
