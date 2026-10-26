Import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'watch_video_player_section.dart';
import 'watch_like_burst_overlay.dart';
import 'watch_video_status_overlays.dart';
import 'watch_top_controls_bar.dart';
import 'watch_reward_button.dart';
import 'watch_action_buttons_row.dart';
import 'watch_title_info_section.dart';
import 'watch_swipe_guide_overlay.dart';
import 'watch_paywall_popup.dart';
import 'watch_vip_upsell_popup.dart';

class WatchEpisodePageItem extends StatelessWidget {
  const WatchEpisodePageItem({
    super.key,
    required this.epNum,
    required this.ep,
    required this.isActive,
    required this.player,
    required this.ready,
    required this.isUnlocked,
    required this.hasVideo,
    required this.series,
    required this.cfg,
    required this.coinSystemEnabled,
    required this.allowVipUnlock,
    required this.showVipUpsell,
    required this.allowAdsUnlock,
    required this.canUnlockByAd,
    required this.unlockCost,
    required this.coinsEnabled,
    required this.canUnlockByCoins,
    required this.topPad,
    required this.bottomPad,
    required this.genresLine,
    required this.loadingEpisode,
    required this.isVipUser,
    required this.coinsBalance,
    required this.totalEpisodes,
    required this.controlsVisible,
    required this.videoLoading,
    required this.videoError,
    required this.activeVideoUrl,
    required this.showLikeBurst,
    required this.likeBurstPos,
    required this.likeBurstAnimation,
    required this.likeBurstScale,
    required this.likeBurstOpacity,
    required this.rewardShakeAnimation,
    required this.rewardDismissed,
    required this.showSwipeGuide,
    required this.guideShakeAnimation,
    required this.isLiked,
    required this.likesCount,
    required this.autoUnlockEnabled,
    required this.unlocking,
    required this.adUnlocksToday,
    required this.dailyAdLimit,
    required this.qualityLabel,
    required this.fmtDuration,
    required this.ageRatingAsset,
    required this.coinUnit,
    required this.bg,
    required this.reelsPreview,
    required this.onTap,
    required this.onDoubleTapDown,
    required this.onDoubleTap,
    required this.onToggleControls,
    required this.onSafePopOrHome,
    required this.onToggleLike,
    required this.onOpenEpisodesSheet,
    required this.onOpenMoreSheet,
    required this.onOpenSeriesInfo,
    required this.onWatchNow,
    required this.onTapReward,
    required this.onDismissReward,
    required this.onDismissSwipeGuide,
    required this.onRetryVideo,
    required this.onOpenQualitySheet,
    required this.onPauseAndPushMembership,
    required this.onRecharge,
    required this.onUnlockWithCoins,
    required this.onUnlockWithAd,
    required this.onSetAutoUnlock,
    required this.paywallAnimBuilder,
    required this.episodeNumber,
    this.onTogglePlayback,
  });

  final int epNum;
  final dynamic ep;
  final bool isActive;
  final VideoPlayerController? player;
  final bool ready;
  final bool isUnlocked;
  final bool hasVideo;
  final dynamic series;
  final dynamic cfg;
  final bool coinSystemEnabled;
  final bool allowVipUnlock;
  final bool showVipUpsell;
  final bool allowAdsUnlock;
  final bool canUnlockByAd;
  final int unlockCost;
  final bool coinsEnabled;
  final bool canUnlockByCoins;
  final double topPad;
  final double bottomPad;
  final String genresLine;
  final bool loadingEpisode;
  final bool isVipUser;
  final int coinsBalance;
  final int totalEpisodes;
  final bool controlsVisible;
  final bool videoLoading;
  final String? videoError;
  final String? activeVideoUrl;
  final bool showLikeBurst;
  final Offset likeBurstPos;
  final Animation<double> likeBurstAnimation;
  final double Function(double t) likeBurstScale;
  final double Function(double t) likeBurstOpacity;
  final Animation<double> rewardShakeAnimation;
  final bool rewardDismissed;
  final bool showSwipeGuide;
  final Animation<double> guideShakeAnimation;
  final bool isLiked;
  final int likesCount;
  final bool autoUnlockEnabled;
  final bool unlocking;
  final int adUnlocksToday;
  final int dailyAdLimit;
  final String Function(dynamic ep, dynamic t) qualityLabel;
  final String Function(Duration d) fmtDuration;
  final String Function(String rating) ageRatingAsset;
  final String coinUnit;
  final String bg;
  final bool reelsPreview;
  final VoidCallback onTap;
  final void Function(TapDownDetails d) onDoubleTapDown;
  final VoidCallback onDoubleTap;
  final VoidCallback onToggleControls;
  final VoidCallback onSafePopOrHome;
  final VoidCallback onToggleLike;
  final VoidCallback onOpenEpisodesSheet;
  final VoidCallback onOpenMoreSheet;
  final VoidCallback onOpenSeriesInfo;
  final VoidCallback onWatchNow;
  final VoidCallback onTapReward;
  final VoidCallback onDismissReward;
  final VoidCallback onDismissSwipeGuide;
  final VoidCallback onRetryVideo;
  final void Function(dynamic ep) onOpenQualitySheet;
  final VoidCallback onPauseAndPushMembership;
  final VoidCallback onRecharge;
  final VoidCallback onUnlockWithCoins;
  final VoidCallback onUnlockWithAd;
  final ValueChanged<bool> onSetAutoUnlock;
  final Widget Function({required int episodeNumber, required Widget child}) paywallAnimBuilder;
  final int episodeNumber;
  final VoidCallback? onTogglePlayback;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onDoubleTapDown: onDoubleTapDown,
      onDoubleTap: onDoubleTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.black),
          WatchVideoPlayerSection(
            ready: ready,
            isUnlocked: isUnlocked,
            hasVideo: hasVideo,
            videoLoading: videoLoading,
            videoError: videoError,
            player: player,
            bg: bg,
            ep: ep,
            series: series,
            isVipUser: isVipUser,
            bottomPad: bottomPad,
            controlsVisible: controlsVisible,
            qualityLabel: qualityLabel,
            fmtDuration: fmtDuration,
            onOpenQualitySheet: onOpenQualitySheet,
            onPauseAndPushMembership: onPauseAndPushMembership,
            reelsPreview: reelsPreview,
            onTogglePlayback: onTogglePlayback,
            epNum: epNum,
            totalEpisodes: totalEpisodes,
            onOpenEpisodesSheet: onOpenEpisodesSheet,
          ),
          WatchLikeBurstOverlay(
            showLikeBurst: showLikeBurst,
            isActive: isActive,
            likeBurstPos: likeBurstPos,
            likeBurstAnimation: likeBurstAnimation,
            likeBurstScale: likeBurstScale,
            likeBurstOpacity: likeBurstOpacity,
          ),
          WatchVideoStatusOverlays(
            isUnlocked: isUnlocked,
            hasVideo: hasVideo,
            loadingEpisode: loadingEpisode,
            isActive: isActive,
            videoLoading: videoLoading,
            videoError: videoError,
            onRetryVideo: onRetryVideo,
            activeVideoUrl: activeVideoUrl,
          ),
          if (isUnlocked) ...[
            WatchRewardButton(
              topPad: topPad,
              rewardShakeAnimation: rewardShakeAnimation,
              rewardDismissed: rewardDismissed,
              onTapReward: onTapReward,
              onDismiss: onDismissReward,
            ),
            WatchActionButtonsRow(
              bottomPad: bottomPad,
              isLiked: isLiked,
              likesCount: likesCount,
              onToggleLike: onToggleLike,
              seriesId: series.id,
              reelsPreview: reelsPreview,
              onOpenEpisodesSheet: onOpenEpisodesSheet,
              onOpenMoreSheet: onOpenMoreSheet,
              controlsVisible: controlsVisible,
              isUnlocked: isUnlocked,
            ),
            WatchTitleInfoSection(
              bottomPad: bottomPad,
              genresLine: genresLine,
              seriesTitle: series.title,
              contentRating: series.contentRating,
              synopsis: series.synopsis,
              reelsPreview: reelsPreview,
              ageRatingAsset: ageRatingAsset,
              onOpenSeriesInfo: onOpenSeriesInfo,
              onWatchNow: onWatchNow,
              controlsVisible: controlsVisible,
            ),
          ],
          WatchSwipeGuideOverlay(
            showSwipeGuide: isActive && isUnlocked && hasVideo && showSwipeGuide,
            bottomPad: bottomPad,
            guideShakeAnimation: guideShakeAnimation,
            onDismiss: onDismissSwipeGuide,
          ),
          if (isActive && !isUnlocked)
            paywallAnimBuilder(
              episodeNumber: episodeNumber,
              child: WatchPaywallPopup(
                episodeNumber: episodeNumber,
                totalEpisodes: totalEpisodes,
                showVipUpsell: showVipUpsell,
                coinsBalance: coinsBalance,
                unlocking: unlocking,
                canUnlockByCoins: canUnlockByCoins,
                canUnlockByAd: canUnlockByAd,
                allowAdsUnlock: allowAdsUnlock,
                unlockCost: unlockCost,
                adUnlocksToday: adUnlocksToday,
                dailyAdLimit: dailyAdLimit,
                autoUnlockEnabled: autoUnlockEnabled,
                coinUnit: coinUnit,
                onRecharge: onRecharge,
                onUnlockWithCoins: onUnlockWithCoins,
                onUnlockWithAd: onUnlockWithAd,
                onSetAutoUnlock: onSetAutoUnlock,
                vipUpsellChild: WatchVipUpsellPopup(
                  onGetVip: onPauseAndPushMembership,
                ),
              ),
            ),
          if (!reelsPreview)
            WatchTopControlsBar(
              topPad: topPad,
              controlsVisible: controlsVisible,
              epNum: epNum,
              totalEpisodes: totalEpisodes,
              onToggleControls: onToggleControls,
              onSafePopOrHome: onSafePopOrHome,
              isUnlocked: isUnlocked,
            ),
        ],
      ),
    );
  }
}
