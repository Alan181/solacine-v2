import 'package:flutter/material.dart';
import 'package:solacine_mobile/app/i18n.dart';

class RewardsAppBarHeader extends StatelessWidget {
  const RewardsAppBarHeader({
    super.key,
    this.coins = 0,
    required this.onBackPressed,
  });

  final int coins;
  final VoidCallback onBackPressed;

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
      child: SizedBox(
        height: 44,
        child: Stack(
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: IconButton(
                onPressed: onBackPressed,
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                color: Colors.white.withValues(alpha: 0.90),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: Text(
                t.t('rewards'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
