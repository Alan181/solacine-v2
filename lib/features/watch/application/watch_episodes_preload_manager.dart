import 'package:media_kit/media_kit.dart';

/// Preloading manager for drama series episodes.
/// Pre-warms video player buffers for upcoming episodes using media_kit
/// so swiping between episodes is instantaneous with zero stutter or loading spinner.
class WatchEpisodesPreloadManager {
  WatchEpisodesPreloadManager._();

  static final Map<String, Player> _playerCache = <String, Player>{};
  static final Set<String> _inFlightUrls = <String>{};

  /// Takes a pre-warmed initialized player for [url], if available.
  static Player? takePrewarmed(String url) {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return null;
    final player = _playerCache.remove(cleanUrl);
    if (player != null) {
      return player;
    }
    try {
      player?.dispose();
    } catch (_) {}
    return null;
  }

  /// Checks if [url] is already pre-warmed.
  static bool hasPrewarmed(String url) {
    return _playerCache.containsKey(url.trim());
  }

  /// Pre-warms and buffers the video start for [url] in the background.
  static Future<void> preloadUrl(String url) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return;
    if (_playerCache.containsKey(cleanUrl) || _inFlightUrls.contains(cleanUrl)) return;

    _inFlightUrls.add(cleanUrl);
    try {
      final player = Player();
      // Buka media di background tanpa langsung memutar suaranya
      await player.open(Media(cleanUrl), play: false);

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
    for (final player in _playerCache.values) {
      try {
        player.dispose();
      } catch (_) {}
    }
    _playerCache.clear();
    _inFlightUrls.clear();
  }
}
