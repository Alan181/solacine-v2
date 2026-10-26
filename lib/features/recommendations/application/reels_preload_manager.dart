import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import '../../watch/data/watch_api.dart';

/// In-memory preloading manager for reels drama content.
/// Pre-caches drama metadata and pre-warms video player buffers using media_kit so
/// swiping between reels is instantaneous without lag.
class ReelsPreloadManager {
  ReelsPreloadManager._();

  static final Map<String, WatchDataDto> _dataCache = <String, WatchDataDto>{};
  static final Map<String, Player> _playerCache = <String, Player>{};
  static final Set<String> _inFlightSlugs = <String>{};

  static WatchDataDto? getCachedData(String slug) => _dataCache[slug];

  static void cacheData(String slug, WatchDataDto data) {
    _dataCache[slug] = data;
  }

  static Player? takePrewarmedPlayer(String url) {
    final player = _playerCache.remove(url);
    if (player != null) {
      return player;
    }
    try {
      player?.dispose();
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
                extra: {'reels_preview': true}, // Pengaman agar prefetch tidak masuk history database
              ),
            );
        _dataCache[cleanSlug] = data;
      }

      final ep = data.episodes.isNotEmpty ? data.episodes.first : null;
      final videoUrl = ep?.videoUrl.trim() ?? '';
      if (videoUrl.isNotEmpty && !_playerCache.containsKey(videoUrl)) {
        // Optimasi: Menambahkan PlayerConfiguration untuk cache HLS & Buffer (32MB)
        final player = Player(
          configuration: const PlayerConfiguration(
            bufferSize: 32 * 1024 * 1024, // 32 MB demuxer cache size untuk kestabilan HLS stream
          ),
        );

        // Buka media di background dengan header opsional
        await player.open(
          Media(
            videoUrl,
            httpHeaders: const {
              'User-Agent': 'SolacineMobile/1.0',
            },
          ),
          play: false,
        );
        await player.setPlaylistMode(PlaylistMode.single);

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
    } catch (e) {
      debugPrint('[ReelsPreloadManager] Prefetch error for $cleanSlug: $e');
    } finally {
      _inFlightSlugs.remove(cleanSlug);
    }
  }

  static void disposeAll() {
    for (final player in _playerCache.values) {
      try {
        player.dispose();
      } catch (_) {}
    }
    _playerCache.clear();
    _dataCache.clear();
    _inFlightSlugs.clear();
  }
}
