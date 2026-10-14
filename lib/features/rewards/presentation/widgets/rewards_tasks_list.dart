import 'package:flutter/material.dart';
import '../../../../app/i18n.dart';
import '../../data/rewards_api.dart';
import 'rewards_task_card.dart';

class RewardsTasksList extends StatelessWidget {
  const RewardsTasksList({
    super.key,
    required this.tasks,
    required this.claimedTaskIds,
    required this.loadingTaskIds,
    required this.pendingLinkTaskId,
    this.countingDownTaskId,
    this.countdownSeconds = 0,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onStartLinkTask,
    required this.onClaimLinkTask,
    required this.onOpenUrl,
    required this.adsTasks,
    required this.isVip,
  });

  final List<RewardTask> tasks;
  final Set<int> claimedTaskIds;
  final Set<int> loadingTaskIds;
  final int? pendingLinkTaskId;
  final int? countingDownTaskId;
  final int countdownSeconds;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final void Function(RewardTask task) onStartLinkTask;
  final void Function(RewardTask task) onClaimLinkTask;
  final void Function(String url) onOpenUrl;
  final List<RewardTask> adsTasks;
  final bool isVip;

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    final visibleTasks = expanded ? tasks : tasks.take(4).toList();
    final hasMoreTasks = tasks.length > 4;
    final showNoTasks = visibleTasks.isEmpty && adsTasks.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Daily Tasks Section Header (exactly like website)
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xff121215),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xff1f1f25)),
              ),
              child: Icon(
                Icons.checklist_rounded,
                size: 20,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.t('daily_tasks'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    t.t('daily_tasks_desc'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.50),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (visibleTasks.isNotEmpty) ...[
          ...visibleTasks.map((task) {
            final claimed = claimedTaskIds.contains(task.id);
            final loading = loadingTaskIds.contains(task.id);
            final isLink = task.type == 'link';
            final pending = pendingLinkTaskId == task.id;
            final isCountingDown = countingDownTaskId == task.id && countdownSeconds > 0;
            final claimReady = pending;

            final enabled = !claimed && !loading && !isCountingDown;
            final buttonLabel = claimed
                ? t.t('claimed')
                : isCountingDown
                    ? '${countdownSeconds}s'
                    : isLink
                        ? pending
                            ? t.t('claim')
                            : t.t('start')
                        : t.t('start');

            VoidCallback? tap;
            if (enabled) {
              if (isLink) {
                tap = pending ? () => onClaimLinkTask(task) : () => onStartLinkTask(task);
              } else {
                final canOpen = task.targetUrl.trim().isNotEmpty;
                tap = canOpen ? () => onOpenUrl(task.targetUrl) : null;
              }
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RewardsTaskCard(
                task: task,
                title: task.title,
                rewardCoins: task.rewardCoins,
                claimReady: claimReady,
                loading: loading,
                buttonLabel: buttonLabel,
                countdownSeconds: isCountingDown ? countdownSeconds : null,
                onTap: tap,
              ),
            );
          }),
        ] else if (showNoTasks) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                t.t('no_tasks_available'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.50),
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
        if (hasMoreTasks) ...[
          const SizedBox(height: 4),
          Center(
            child: SizedBox(
              height: 36,
              child: OutlinedButton(
                onPressed: onToggleExpanded,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: 0.85),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      expanded ? t.t('close') : t.t('see_all'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
