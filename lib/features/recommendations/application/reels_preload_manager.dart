import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../watch/data/watch_api.dart';

/// In-memory preloading manager for reels drama content.
/// Pre-caches drama metadata so switching between reels is instantaneous.
class ReelsPreloadManager {
  ReelsPreloadManager._();

  static final Map<String, WatchDataDto> _dataCache = <String, WatchDataDto>{};
  static final Set<String> _inFlightSlugs = <String>{};

  static WatchDataDto? getCachedData(String slug) => _dataCache[slug];

  static void cacheData(String slug, WatchDataDto data) {
    _dataCache[slug] = data;
  }

  /// Compatibility method for taking prewarmed controller (returns null since BetterPlayer initializes dynamically).
  static dynamic takePrewarmedController(String url) {
    return null;
  }

  /// Pre-fetches metadata for [slug] in the background.
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
    } catch (_) {
      // Ignore background prefetch network errors
    } finally {
      _inFlightSlugs.remove(cleanSlug);
    }
  }

  static void disposeAll() {
    _dataCache.clear();
    _inFlightSlugs.clear();
  }
}
