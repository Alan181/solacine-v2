import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../watch/data/watch_api.dart';

/// In-memory preloading manager for reels drama content.
/// Pre-caches drama metadata and pre-warms video player buffers so
/// swiping between reels is instantaneous without lag.
class ReelsPreloadManager {
  ReelsPreloadManager._();

  static final Map<String, WatchDataDto> _dataCache = <String, WatchDataDto>{};
  static final Map<String, VideoPlayerController> _controllerCache = <String, VideoPlayerController>{};
  static final Set<String> _inFlightSlugs = <String>{};

  static WatchDataDto? getCachedData(String slug) => _dataCache[slug];

  static void cacheData(String slug, WatchDataDto data) {
    _dataCache[slug] = data;
  }

  static VideoPlayerController? takePrewarmedController(String url) {
    final c = _controllerCache.remove(url);
    if (c != null && c.value.isInitialized) {
      return c;
    }
    try {
      c?.dispose();
    } catch (_) {}
    return null;
  }

  /// Pre-fetches metadata and buffers the video start for [slug] in the background.
  static Future<void> prefetch({
    required WidgetRef ref,
    required String slug,
    int episode = 1,
  }) async {
    final cleanSlug = slug.trim();
    if (cleanSlug.isEmpty) return;
    if (_inFlightSlugs.contains(cleanSlug)) return;

    _inFlightSlugs.add(cleanSlug);
    try {
      var data = _dataCache[cleanSlug];
      if (data == null) {
        data = await ref.read(watchApiProvider).show(
              slug: cleanSlug,
              episodeNumber: episode,
              episodesPerPage: 1,
              options: Options(
                extra: {'reels_preview': true}, // <--- Pengaman agar prefetch tidak masuk history database
              ),
            );
        _dataCache[cleanSlug] = data;
      }

      final ep = data.episodes.isNotEmpty ? data.episodes.first : null;
      final videoUrl = ep?.videoUrl.trim() ?? '';
      if (videoUrl.isNotEmpty && !_controllerCache.containsKey(videoUrl)) {
        
        // --- PENAMBAHAN FORMAT HINT UNTUK KONSISTENSI PEMUTARAN ---
        final isHls = videoUrl.contains('.m3u8') || videoUrl.contains('/hls/');
        final isMp4 = videoUrl.toLowerCase().endsWith('.mp4') || videoUrl.contains('.mp4?');

        final c = VideoPlayerController.networkUrl(
          Uri.parse(videoUrl),
          formatHint: isHls ? VideoFormat.hls : (isMp4 ? VideoFormat.other : null),
        );

        await c.initialize();
        await c.setLooping(true);

        // Keep maximum 2 pre-warmed controllers to prevent RAM bloat
        if (_controllerCache.length >= 2) {
          final oldestKey = _controllerCache.keys.first;
          final old = _controllerCache.remove(oldestKey);
          try {
            old?.dispose();
          } catch (_) {}
        }
        _controllerCache[videoUrl] = c;
      }
    } catch (_) {
      // Ignore background prefetch network errors
    } finally {
      _inFlightSlugs.remove(cleanSlug);
    }
  }

  static void disposeAll() {
    for (final c in _controllerCache.values) {
      try {
        c.dispose();
      } catch (_) {}
    }
    _controllerCache.clear();
    _dataCache.clear();
    _inFlightSlugs.clear();
  }
}
