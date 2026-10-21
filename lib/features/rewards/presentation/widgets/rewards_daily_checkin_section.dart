import 'package:flutter/material.dart';
import '../../../../app/i18n.dart';

class RewardsDailyCheckinSection extends StatelessWidget {
  const RewardsDailyCheckinSection({
    super.key,
    required this.schedule,
    required this.dayIndex,
    required this.claimedToday,
    required this.loading,
    required this.onClaim,
  });

  final List<int> schedule;
  final int dayIndex;
  final bool claimedToday;
  final bool loading;
  final VoidCallback? onClaim;

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    final items = schedule.isNotEmpty ? schedule : const <int>[10, 20, 30, 40, 50, 60, 70];
    final activeCoins = (dayIndex >= 1 && dayIndex <= items.length) ? items[dayIndex - 1] : 20;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xff09090b),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xff18181b)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row (Title, subtitle, Resets every 7 days badge)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.t('checkin_schedule_title'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.t('checkin_schedule_desc'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.50),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xff121215),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xff1f1f25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 11,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      t.t('resets_every_7_days'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.70),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 7 Days Cards
          SizedBox(
            height: 98,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: items.length.clamp(1, 7),
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, idx) {
                final d = idx + 1;
                final coins = items[idx];
                final isClaimed = d < dayIndex || (d == dayIndex && claimedToday);
                final isActiveToday = d == dayIndex && !claimedToday;
                final isLast = d == items.length;

                return _CheckinCard(
                  day: d,
                  coins: coins,
                  isClaimed: isClaimed,
                  isActiveToday: isActiveToday,
                  isLast: isLast,
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0xff1f1f25), height: 1),
          const SizedBox(height: 12),
          // Bottom Claim Row
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xff121215),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xff1f1f25)),
                ),
                child: Icon(
                  Icons.bolt_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      claimedToday
                          ? t.t('already_claimed_today')
                          : '${t.t('claim_daily_coins')} (+$activeCoins)',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      claimedToday
                          ? t.t('come_back_tomorrow')
                          : t.t('dont_break_streak'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 34,
                child: FilledButton(
                  onPressed: claimedToday || loading ? null : onClaim,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xff09090b),
                    disabledBackgroundColor: const Color(0xff1f1f25),
                    disabledForegroundColor: Colors.white.withValues(alpha: 0.35),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
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
                            Icon(
                              claimedToday ? Icons.check_rounded : Icons.card_giftcard_rounded,
                              size: 14,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              claimedToday
                                  ? t.t('claimed_today')
                                  : '${t.t('claim')} (+$activeCoins)',
                            ),
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

class _CheckinCard extends StatelessWidget {
  const _CheckinCard({
    required this.day,
    required this.coins,
    required this.isClaimed,
    required this.isActiveToday,
    required this.isLast,
  });

  final int day;
  final int coins;
  final bool isClaimed;
  final bool isActiveToday;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    final dayLabelWord = t.t('day').isNotEmpty ? t.t('day') : 'Day';

    if (isClaimed) {
      return Container(
        width: 62,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0xff121215),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xff1f1f25)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$dayLabelWord $day',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.40),
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xff10b981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: const Color(0xff10b981).withValues(alpha: 0.25)),
              ),
              child: const Icon(Icons.check_rounded, color: Color(0xff34d399), size: 15),
            ),
            Text(
              '+$coins',
              style: const TextStyle(
                color: Color(0xff34d399),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.lineThrough,
                decorationColor: Color(0xff34d399),
              ),
            ),
          ],
        ),
      );
    }

    if (isActiveToday) {
      return Container(
        width: 66,
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0xff18181f),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xff52525b), width: 1.3),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.05),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                t.t('today').toUpperCase(),
                style: const TextStyle(
                  color: Color(0xff09090b),
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(Icons.toll_rounded, color: Colors.white, size: 15),
            ),
            Text(
              '+$coins',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
    }

    // Future / locked day
    return Container(
      width: 62,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xff121215),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xff1f1f25)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$dayLabelWord $day',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.40),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (isLast) ...[
                const SizedBox(width: 2),
                const Text('★', style: TextStyle(color: Color(0xfffbbf24), fontSize: 9)),
              ],
            ],
          ),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xff0d0d10),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(
              Icons.lock_rounded,
              color: Colors.white.withValues(alpha: 0.30),
              size: 13,
            ),
          ),
          Text(
            '+$coins',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
