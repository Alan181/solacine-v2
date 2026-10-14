import 'package:flutter/material.dart';
import '../../../../app/i18n.dart';
import '../../data/rewards_api.dart';

class RewardsWatchAdsSection extends StatelessWidget {
  const RewardsWatchAdsSection({
    super.key,
    required this.title,
    required this.tasks,
    required this.loading,
    required this.onTap,
  });

  final String title;
  final List<RewardTask> tasks;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    if (tasks.isEmpty) return const SizedBox.shrink();

    final totalReward = tasks.map((e) => e.rewardCoins).fold<int>(0, (a, b) => a + b);
    final buttonDisabled = loading || onTap == null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xff09090b),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xff18181b)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xff121215),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xff1f1f25)),
                ),
                child: const Icon(
                  Icons.play_circle_outline_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.t('watch_rewarded_videos'),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xff1f1f25),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xff27272a)),
                          ),
                          child: Text(
                            '${tasks.length} ${t.t('ads_available')}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.70),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.t('watch_ads_desc'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.50),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0xff1f1f25), height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xff121215),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xff1f1f25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.toll_rounded, color: Color(0xfffbbf24), size: 14),
                    const SizedBox(width: 6),
                    Text(
                      t.t('reward_colon'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '+$totalReward',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      t.t('wallet_coins'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 38,
                child: FilledButton(
                  onPressed: buttonDisabled ? null : onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xff09090b),
                    disabledBackgroundColor: const Color(0xff1f1f25),
                    disabledForegroundColor: Colors.white.withValues(alpha: 0.35),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xff09090b)),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.play_arrow_rounded, size: 16),
                            const SizedBox(width: 4),
                            Text(t.t('watch_ads')),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
