import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' as media_kit_pkg;
import '../../watch/data/watch_api.dart';

/// In-memory preloading manager for reels drama content using media_kit.
/// Pre-caches drama metadata and pre-warms video player buffers so
/// swiping between reels is instantaneous without lag.
class ReelsPreloadManager {
  ReelsPreloadManager._();

  static final Map<String, WatchDataDto> _dataCache = <String, WatchDataDto>{};
  static final Map<String, media_kit_pkg.Player> _playerCache = <String, media_kit_pkg.Player>{};
  static final Set<String> _inFlightSlugs = <String>{};

  static WatchDataDto? getCachedData(String slug) => _dataCache[slug];

  static void cacheData(String slug, WatchDataDto data) {
    _dataCache[slug] = data;
  }

  static media_kit_pkg.Player? takePrewarmedController(String url) {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return null;
    final p = _playerCache.remove(cleanUrl);
    if (p != null) {
      return p;
    }
    return null;
  }

  /// Pre-fetches metadata and buffers the video start for [slug] in the background using media_kit.
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
      if (videoUrl.isNotEmpty && !_playerCache.containsKey(videoUrl)) {
        final player = media_kit_pkg.Player();
        await player.open(media_kit_pkg.Media(videoUrl), play: false);

        // Keep maximum 2 pre-warmed players to prevent RAM bloat
        if (_playerCache.length >= 2) {
          final oldestKey = _playerCache.keys.first;
          final old = _playerCache.remove(oldestKey);
          try {
            old?.dispose();
          } catch (_) {}
        }
        _playerCache[videoUrl] = player;
      }
    } catch (_) {
      // Ignore background prefetch network errors
    } finally {
      _inFlightSlugs.remove(cleanSlug);
    }
  }

  static void disposeAll() {
    for (final p in _playerCache.values) {
      try {
        p.dispose();
      } catch (_) {}
    }
    _playerCache.clear();
    _dataCache.clear();
    _inFlightSlugs.clear();
  }
}
