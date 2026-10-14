import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dramereel_mobile/app/i18n.dart';

class WatchVideoStatusOverlays extends StatelessWidget {
  const WatchVideoStatusOverlays({
    super.key,
    required this.isUnlocked,
    required this.hasVideo,
    required this.loadingEpisode,
    required this.isActive,
    required this.videoLoading,
    required this.videoError,
    required this.onRetryVideo,
    required this.activeVideoUrl,
  });

  final bool isUnlocked;
  final bool hasVideo;
  final bool loadingEpisode;
  final bool isActive;
  final bool videoLoading;
  final String? videoError;
  final VoidCallback onRetryVideo;
  final String? activeVideoUrl;

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);

    if (isUnlocked && !hasVideo) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t.t('no_video_available'),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontWeight: FontWeight.w500, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                t.t('no_video_available_desc'),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.70), fontWeight: FontWeight.w500, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (loadingEpisode || (isActive && isUnlocked && hasVideo && videoLoading)) {
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

    if (isActive && isUnlocked && hasVideo && videoError != null) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.60),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t.t('video_failed'),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontWeight: FontWeight.w500, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                t.t('video_failed_desc'),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.70), fontWeight: FontWeight.w500, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: onRetryVideo,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xfffbbf24),
                      textStyle: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    child: Text(t.t('retry')),
                  ),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: () async {
                      final u = activeVideoUrl;
                      if (u == null || u.trim().isEmpty) return;
                      await launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withValues(alpha: 0.90),
                      textStyle: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    child: Text(t.t('open_external')),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
