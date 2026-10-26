import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:solacine_mobile/app/i18n.dart';
import 'package:solacine_mobile/shared/widgets/app_cached_image.dart';
import 'watch_seek_bar.dart';

class WatchVideoPlayerSection extends StatelessWidget {
  const WatchVideoPlayerSection({
    super.key,
    required this.ready,
    required this.isUnlocked,
    required this.hasVideo,
    required this.videoLoading,
    required this.videoError,
    required this.player,
    required this.bg,
    required this.ep,
    required this.series,
    required this.isVipUser,
    required this.bottomPad,
    required this.controlsVisible,
    required this.qualityLabel,
    required this.fmtDuration,
    required this.onOpenQualitySheet,
    required this.onPauseAndPushMembership,
    this.reelsPreview = false,
    this.onTogglePlayback,
    this.epNum,
    this.totalEpisodes,
    this.onOpenEpisodesSheet,
  });

  final bool ready;
  final bool isUnlocked;
  final bool hasVideo;
  final bool videoLoading;
  final String? videoError;
  final Player? player;
  final String bg;
  final dynamic ep;
  final dynamic series;
  final bool isVipUser;
  final double bottomPad;
  final bool controlsVisible;
  final String Function(dynamic ep, AppI18n t) qualityLabel;
  final String Function(Duration d) fmtDuration;
  final void Function(dynamic ep) onOpenQualitySheet;
  final VoidCallback onPauseAndPushMembership;
  final bool reelsPreview;
  final VoidCallback? onTogglePlayback;
  final int? epNum;
  final int? totalEpisodes;
  final VoidCallback? onOpenEpisodesSheet;

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    final p = player;

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        
        // 1. Selalu render background poster di bawah agar tidak ada flash hitam kosong
        _buildBackground(bg),

        // 2. Video player ditumpuk di atas background dengan AnimatedOpacity untuk transisi halus
        if (p != null)
          AnimatedOpacity(
            opacity: ready ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: RepaintBoundary(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: (p.state.width ?? 0) > 0 ? (p.state.width!).toDouble() : 9.0,
                  height: (p.state.height ?? 0) > 0 ? (p.state.height!).toDouble() : 16.0,
                  child: Video(
                    controller: VideoController(p),
                    controls: NoVideoControls,
                  ),
                ),
              ),
            ),
          ),

        // Cinema bottom gradient shadow to guarantee controls, title and buttons readability
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: reelsPreview ? 360 : 270,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.15),
                    Colors.black.withValues(alpha: 0.50),
                    Colors.black.withValues(alpha: 0.82),
                    Colors.black.withValues(alpha: 0.95),
                  ],
                  stops: const [0.0, 0.28, 0.58, 0.82, 1.0],
                ),
              ),
            ),
          ),
        ),
        // Subtle iOS top gradient for status bar
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 90,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.40),
                    Colors.black.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
        ),
        // Center overlay: iOS loading spinner when buffering/loading, OR play button when paused
        if (ready && isUnlocked && hasVideo && videoError == null && p != null)
          StreamBuilder<bool>(
            stream: p.stream.buffering,
            builder: (context, bufferingSnapshot) {
              return StreamBuilder<bool>(
                stream: p.stream.playing,
                builder: (context, playingSnapshot) {
                  final isBuffering = (bufferingSnapshot.data ?? false) || videoLoading;
                  
                  if (isBuffering) {
                    return Center(
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.50),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.20),
                            width: 1.5,
                          ),
                        ),
                        child: const Center(
                          child: CupertinoActivityIndicator(
                            radius: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    );
                  }

                  final isPlaying = playingSnapshot.data ?? true;
                  final isPaused = !isPlaying;
                  if (!isPaused) return const SizedBox.shrink();

                  return Center(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (onTogglePlayback != null) {
                          onTogglePlayback!();
                        } else {
                          p.play();
                        }
                      },
                      child: Container(
                        width: 74,
                        height: 74,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.8),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.50), blurRadius: 24, spreadRadius: 2),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        if (ready && isUnlocked && p != null) ..._buildBottomControls(context, t, p),
      ],
    );
  }

  Widget _buildBackground(String bg) {
    if (bg.isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xff0b0b0b),
              Colors.black,
            ],
          ),
        ),
      );
    }
    return AppCachedImage(
      imageUrl: bg,
      fit: BoxFit.cover,
      errorWidget: (_) => Container(color: const Color(0xff0b0b0b)),
    );
  }

  List<Widget> _buildBottomControls(BuildContext context, AppI18n t, Player p) {
    if (reelsPreview) {
      return [
        PositionedDirectional(
          start: 0,
          end: 0,
          bottom: bottomPad,
          child: WatchSeekBar(
            controller: p,
            activeColor: const Color(0xFFB0B0B0),
            inactiveColor: const Color(0xFF333333).withValues(alpha: 0.60),
          ),
        ),
      ];
    }

    return [
      PositionedDirectional(
        start: 14,
        end: 14,
        bottom: bottomPad + 38,
        child: IgnorePointer(
          ignoring: !controlsVisible,
          child: AnimatedOpacity(
            opacity: controlsVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (ready && isUnlocked)
                  StreamBuilder<Duration>(
                    stream: p.stream.position,
                    builder: (context, snapshot) {
                      final position = snapshot.data ?? p.state.position;
                      final duration = p.state.duration;
                      return Text(
                        '${fmtDuration(position)} / ${fmtDuration(duration)}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.85),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 3),
                WatchSeekBar(
                  controller: p,
                  activeColor: const Color(0xFFE50914),
                  inactiveColor: Colors.white.withValues(alpha: 0.22),
                ),
              ],
            ),
          ),
        ),
      ),
      PositionedDirectional(
        start: 14,
        end: 14,
        bottom: bottomPad + 8,
        child: IgnorePointer(
          ignoring: !controlsVisible,
          child: AnimatedOpacity(
            opacity: controlsVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 180),
            child: Row(
              children: [
                if (ep != null)
                  InkWell(
                    onTap: () => onOpenQualitySheet(ep),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.24), width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tune_rounded, size: 11, color: Colors.white.withValues(alpha: 0.90)),
                          const SizedBox(width: 3.5),
                          Text(
                            qualityLabel(ep, t),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  const SizedBox.shrink(),
                if (series.isDubbed) ...[
                  const SizedBox(width: 6),
                  Container(
                    height: 22,
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xFFFF5A5F),
                          Color(0xFFD946EF),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Center(
                      child: Text(
                        t.t('dubbed'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 9.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (isVipUser)
                  Container(
                    height: 22,
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.50), width: 0.9),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/player_vip.png',
                          width: 13,
                          height: 13,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.workspace_premium_rounded,
                            size: 12,
                            color: Color(0xFFFFD700),
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Text(
                          'VIP',
                          style: TextStyle(
                            color: Color(0xFFFFDF7A),
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  InkWell(
                    onTap: onPauseAndPushMembership,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.45),
                          width: 0.9,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/images/player_vip.png',
                            width: 14,
                            height: 14,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.workspace_premium_rounded,
                              size: 13,
                              color: Color(0xFFFFD700),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            t.t('join_membership'),
                            style: const TextStyle(
                              color: Color(0xFFFFDF7A),
                              fontWeight: FontWeight.w600,
                              fontSize: 9.5,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ];
  }
}
