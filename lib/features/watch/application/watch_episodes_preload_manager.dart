import 'package:video_player/video_player.dart';

/// Preloading manager for drama series episodes.
/// Pre-warms video player buffers for upcoming episodes so swiping
/// between episodes is instantaneous with zero stutter or loading spinner.
class WatchEpisodesPreloadManager {
  WatchEpisodesPreloadManager._();

  static final Map<String, VideoPlayerController> _controllerCache = <String, VideoPlayerController>{};
  static final Set<String> _inFlightUrls = <String>{};

  /// Takes a pre-warmed initialized controller for [url], if available.
  static VideoPlayerController? takePrewarmed(String url) {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return null;
    final c = _controllerCache.remove(cleanUrl);
    if (c != null && c.value.isInitialized) {
      return c;
    }
    try {
      c?.dispose();
    } catch (_) {}
    return null;
  }

  /// Checks if [url] is already pre-warmed and ready.
  static bool hasPrewarmed(String url) {
    final cleanUrl = url.trim();
    final c = _controllerCache[cleanUrl];
    return c != null && c.value.isInitialized;
  }

  /// Pre-warms and buffers the video start for [url] in the background.
  static Future<void> preloadUrl(String url) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return;
    if (_controllerCache.containsKey(cleanUrl) || _inFlightUrls.contains(cleanUrl)) return;

    _inFlightUrls.add(cleanUrl);
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(cleanUrl));
      await c.initialize();
      await c.setLooping(true);

      // Keep maximum 2 pre-warmed controllers to prevent RAM bloat
      while (_controllerCache.length >= 2) {
        final oldestKey = _controllerCache.keys.first;
        final oldest = _controllerCache.remove(oldestKey);
        try {
          oldest?.dispose();
        } catch (_) {}
      }
      _controllerCache[cleanUrl] = c;
    } catch (_) {
      // Ignore background preload errors
    } finally {
      _inFlightUrls.remove(cleanUrl);
    }
  }

  /// Disposes all cached pre-warmed controllers.
  static void disposeAll() {
    for (final c in _controllerCache.values) {
      try {
        c.dispose();
      } catch (_) {}
    }
    _controllerCache.clear();
    _inFlightUrls.clear();
  }
}
