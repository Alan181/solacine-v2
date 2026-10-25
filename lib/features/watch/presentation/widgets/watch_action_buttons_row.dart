import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solacine_mobile/app/i18n.dart';
import 'package:solacine_mobile/features/my_list/application/favorites_controller.dart';
import 'watch_side_button.dart';

class WatchActionButtonsRow extends ConsumerWidget {
  const WatchActionButtonsRow({
    super.key,
    required this.bottomPad,
    required this.isLiked,
    required this.likesCount,
    required this.onToggleLike,
    required this.seriesId,
    required this.reelsPreview,
    required this.onOpenEpisodesSheet,
    required this.onOpenMoreSheet,
    required this.controlsVisible,
    required this.isUnlocked,
  });

  final double bottomPad;
  final bool isLiked;
  final int likesCount;
  final VoidCallback onToggleLike;
  final int seriesId;
  final bool reelsPreview;
  final VoidCallback onOpenEpisodesSheet;
  final VoidCallback onOpenMoreSheet;
  final bool controlsVisible;
  final bool isUnlocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppI18n.of(context);
    final favorites = ref.watch(favoritesIdsProvider).valueOrNull ?? const <int>{};
    final fav = favorites.contains(seriesId);

    // In Reels: Action controls are on the LEFT, and NEVER disappear!
    final showButtons = reelsPreview || controlsVisible;

    if (reelsPreview) {
      return Positioned(
        bottom: bottomPad + 45,
        left: 12,
        child: IgnorePointer(
          ignoring: !showButtons,
          child: AnimatedOpacity(
            opacity: showButtons ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 180),
            child: _buildColumn(context, ref, t, fav),
          ),
        ),
      );
    }

    // Full Series Watch Mode
    return PositionedDirectional(
      bottom: bottomPad + 80,
      end: 10,
      child: IgnorePointer(
        ignoring: !showButtons,
        child: AnimatedOpacity(
          opacity: showButtons ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 180),
          child: _buildColumn(context, ref, t, fav),
        ),
      ),
    );
  }

  Widget _buildColumn(BuildContext context, WidgetRef ref, AppI18n t, bool fav) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Visibility(
          visible: isUnlocked,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: WatchSideButton(
            icon: Icon(
              Icons.favorite_rounded,
              color: isLiked ? const Color(0xFFFF2D55) : Colors.white,
              size: 22,
            ),
            label: likesCount > 0 ? likesCount.toString() : t.t('like'),
            onTap: onToggleLike,
          ),
        ),
        Visibility(
          visible: isUnlocked,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: const SizedBox(height: 10),
        ),
        Visibility(
          visible: isUnlocked,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: WatchSideButton(
            icon: Icon(
              fav ? Icons.star_rounded : Icons.star_border_rounded,
              color: fav ? const Color(0xFFFFB800) : Colors.white,
              size: 23,
            ),
            label: t.t('favorites'),
            onTap: () => ref.read(favoritesIdsProvider.notifier).toggle(seriesId),
          ),
        ),
        Visibility(
          visible: isUnlocked,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: const SizedBox(height: 10),
        ),
        if (!reelsPreview) ...[
          WatchSideButton(
            icon: const Icon(
              Icons.video_collection_rounded,
              color: Colors.white,
              size: 21,
            ),
            label: t.t('Episodes'),
            onTap: onOpenEpisodesSheet,
          ),
          const SizedBox(height: 10),
        ],
        WatchSideButton(
          icon: const Icon(
            Icons.more_horiz_rounded,
            color: Colors.white,
            size: 22,
          ),
          label: t.t('more'),
          onTap: onOpenMoreSheet,
        ),
      ],
    );
  }
}
