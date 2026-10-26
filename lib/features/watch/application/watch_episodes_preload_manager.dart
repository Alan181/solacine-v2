import 'package:media_kit/media_kit.dart' as media_kit_pkg;

/// Preloading manager for drama series episodes using media_kit.
/// Pre-warms video player buffers for upcoming episodes so swiping
/// between episodes is instantaneous with zero stutter or loading spinner.
class WatchEpisodesPreloadManager {
  WatchEpisodesPreloadManager._();

  static final Map<String, media_kit_pkg.Player> _playerCache = <String, media_kit_pkg.Player>{};
  static final Set<String> _inFlightUrls = <String>{};

  /// Takes a pre-warmed initialized player for [url], if available.
  static media_kit_pkg.Player? takePrewarmed(String url) {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return null;
    final p = _playerCache.remove(cleanUrl);
    if (p != null) {
      return p;
    }
    return null;
  }

  /// Checks if [url] is already pre-warmed.
  static bool hasPrewarmed(String url) {
    final cleanUrl = url.trim();
    return _playerCache.containsKey(cleanUrl);
  }

  /// Pre-warms and buffers the video start for [url] in the background using media_kit.
  static Future<void> preloadUrl(String url) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return;
    if (_playerCache.containsKey(cleanUrl) || _inFlightUrls.contains(cleanUrl)) return;

    _inFlightUrls.add(cleanUrl);
    try {
      final player = media_kit_pkg.Player();
      // Buka media dengan autoplay false agar dia hanya melakukan buffering di background
      await player.open(media_kit_pkg.Media(cleanUrl), play: false);

      // Keep maximum 2 pre-warmed players to prevent RAM bloat
      while (_playerCache.length >= 2) {
        final oldestKey = _playerCache.keys.first;
        final oldest = _playerCache.remove(oldestKey);
        try {
          oldest?.dispose();
        } catch (_) {}
      }
      _playerCache[cleanUrl] = player;
    } catch (_) {
      // Ignore background preload errors
    } finally {
      _inFlightUrls.remove(cleanUrl);
    }
  }

  /// Disposes all cached pre-warmed players.
  static void disposeAll() {
    for (final p in _playerCache.values) {
      try {
        p.dispose();
      } catch (_) {}
    }
    _playerCache.clear();
    _inFlightUrls.clear();
  }
}
