import 'package:flutter/material.dart';
import '../../../../app/i18n.dart';
import '../../data/rewards_api.dart';

class RewardsTaskCard extends StatelessWidget {
  const RewardsTaskCard({
    super.key,
    required this.task,
    required this.title,
    required this.rewardCoins,
    required this.claimReady,
    required this.loading,
    required this.buttonLabel,
    this.countdownSeconds,
    required this.onTap,
  });

  final RewardTask task;
  final String title;
  final int rewardCoins;
  final bool claimReady;
  final bool loading;
  final String buttonLabel;
  final int? countdownSeconds;
  final VoidCallback? onTap;

  static IconData _iconFor(String typeKey) {
    switch (typeKey) {
      case 'ad':
        return Icons.play_arrow_rounded;
      case 'link':
        return Icons.open_in_new_rounded;
      case 'survey':
        return Icons.assignment_rounded;
      case 'bonus':
        return Icons.card_giftcard_rounded;
      case 'social':
        return Icons.share_rounded;
      case 'download':
        return Icons.download_rounded;
      default:
        return Icons.task_alt_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    final buttonDisabled = loading || onTap == null;
    final isClaimed = buttonLabel == t.t('claimed');
    final icon = _iconFor(task.type);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xff09090b),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: claimReady
              ? const Color(0xfffbbf24).withValues(alpha: 0.70)
              : const Color(0xff18181b),
          width: claimReady ? 1.4 : 1.0,
        ),
        boxShadow: claimReady
            ? [
                BoxShadow(
                  color: const Color(0xfffbbf24).withValues(alpha: 0.08),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Icon Box
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xff121215),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xff1f1f25)),
            ),
            child: Icon(
              icon,
              color: Colors.white.withValues(alpha: 0.90),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // 2. Info: Title & Reward pill
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xff121215),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xff1f1f25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.toll_rounded, color: Color(0xfffbbf24), size: 11),
                          const SizedBox(width: 4),
                          Text(
                            '+$rewardCoins ${t.t('wallet_coins')}',
                            style: const TextStyle(
                              color: Color(0xfffbbf24),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (task.typeLabel.trim().isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        task.typeLabel.trim(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.40),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // 3. Action button
          if (isClaimed)
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xff10b981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0xff10b981).withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_rounded, color: Color(0xff34d399), size: 13),
                  const SizedBox(width: 4),
                  Text(
                    t.t('claimed'),
                    style: const TextStyle(
                      color: Color(0xff34d399),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            )
          else if (countdownSeconds != null && countdownSeconds! > 0)
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xff18181b),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0xff27272a)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_outlined, color: Color(0xfffb923c), size: 13),
                  const SizedBox(width: 4),
                  Text(
                    '${countdownSeconds}s',
                    style: const TextStyle(
                      color: Color(0xfffb923c),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 32,
              child: FilledButton(
                onPressed: buttonDisabled ? null : onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: claimReady ? const Color(0xfffbbf24) : Colors.white,
                  foregroundColor: const Color(0xff09090b),
                  disabledBackgroundColor: const Color(0xff1f1f25),
                  disabledForegroundColor: Colors.white.withValues(alpha: 0.35),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
                ),
                child: loading
                    ? const SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xff09090b)),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (claimReady) ...[
                            const Icon(Icons.card_giftcard_rounded, size: 13),
                            const SizedBox(width: 4),
                          ],
                          Text(buttonLabel),
                          if (!claimReady) ...[
                            const SizedBox(width: 3),
                            const Icon(Icons.arrow_forward_rounded, size: 11),
                          ],
                        ],
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
