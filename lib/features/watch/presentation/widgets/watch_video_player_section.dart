import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart' as media_kit_video;
import 'package:solacine_mobile/app/i18n.dart';
import 'package:solacine_mobile/shared/widgets/app_cached_image.dart';

class WatchVideoPlayerSection extends StatelessWidget {
  const WatchVideoPlayerSection({
    super.key,
    required this.ready,
    required this.isUnlocked,
    required this.hasVideo,
    required this.videoLoading,
    required this.videoError,
    required this.mediaKitVideoController,
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
  final media_kit_video.VideoController? mediaKitVideoController;
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
    final controller = mediaKitVideoController;
    final player = controller?.player;

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        
        // 1. Background poster sebagai visual awal yang mulus
        _buildBackground(bg),

        // 2. MediaKit Video Widget langsung aktif begitu controller tersedia (Tanpa menunggu 'ready' yang kaku)
        if (isUnlocked && hasVideo && controller != null)
          Positioned.fill(
            child: media_kit_video.Video(
              controller: controller,
              fit: BoxFit.cover,
              controls: media_kit_video.NoVideoControls,
            ),
          ),

        // 3. Poster penutup transparan: Memudar mulus (fade out) begitu video benar-benar siap berputar
        AnimatedOpacity(
          opacity: (ready && controller != null) ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          child: IgnorePointer(
            child: _buildBackground(bg),
          ),
        ),

        // 4. Cinema bottom gradient shadow
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: reelsPreview ? 360 : 300,
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

        // 5. Subtle iOS top gradient for status bar
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

        // 6. Center Play/Pause Indicator (Muncul interaktif saat disentuh/pause)
        if (ready && isUnlocked && player != null)
          Center(
            child: StreamBuilder<bool>(
              stream: player.stream.playing,
              builder: (context, snapshot) {
                final isPlaying = snapshot.data ?? true;
                if (isPlaying && controlsVisible) return const SizedBox.shrink();
                return GestureDetector(
                  onTap: onTogglePlayback,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                    ),
                    child: Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                );
              },
            ),
          ),

        // 7. Bottom Controls, Progress Bar & Duration
        if (ready && isUnlocked && player != null) ..._buildInteractiveBottomBar(context, t, player),
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

  List<Widget> _buildInteractiveBottomBar(BuildContext context, AppI18n t, dynamic player) {
    if (reelsPreview) {
      return [];
    }

    return [
      PositionedDirectional(
        start: 14,
        end: 14,
        bottom: bottomPad + 6,
        child: IgnorePointer(
          ignoring: !controlsVisible,
          child: AnimatedOpacity(
            opacity: controlsVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 180),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress Bar & Durasi (Menit:Detik)
                StreamBuilder<Duration>(
                  stream: player.stream.position,
                  builder: (context, posSnapshot) {
                    final position = posSnapshot.data ?? player.state.position;
                    final duration = player.state.duration;
                    
                    final maxSec = duration.inSeconds.toDouble();
                    final currentSec = position.inSeconds.toDouble().clamp(0.0, maxSec > 0 ? maxSec : 1.0);

                    return Column(
                      children: [
                        if (duration > Duration.zero)
                          SizedBox(
                            height: 16,
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 2.5,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                                activeTrackColor: const Color(0xffef233c),
                                inactiveTrackColor: Colors.white.withValues(alpha: 0.25),
                                thumbColor: Colors.white,
                              ),
                              child: Slider(
                                value: currentSec,
                                min: 0.0,
                                max: maxSec > 0 ? maxSec : 1.0,
                                onChanged: (val) {
                                  player.seek(Duration(seconds: val.toInt()));
                                },
                              ),
                            ),
                          ),
                        const SizedBox(height: 2),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                fmtDuration(position),
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.w500),
                              ),
                              Text(
                                fmtDuration(duration),
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 6),
                // Baris Tombol Kualitas, Dubbed, dan VIP
                Row(
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
                          padding: const EdgeInsets.symmetric(horizontal: 14),
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
              ],
            ),
          ),
        ),
      ),
    ];
  }
}
