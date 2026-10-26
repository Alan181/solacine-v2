import 'package:flutter/foundation.dart';

/// Preloading manager for drama series episodes.
class WatchEpisodesPreloadManager {
  WatchEpisodesPreloadManager._();

  static final Set<String> _preloadedUrls = <String>{};

  /// Takes a pre-warmed reference (returns null since BetterPlayer initializes on demand).
  static dynamic takePrewarmed(String url) {
    return null;
  }

  /// Checks if [url] is already preloaded.
  static bool hasPrewarmed(String url) {
    return _preloadedUrls.contains(url.trim());
  }

  /// Preloads URL or marks it as cached for upcoming episodes.
  static Future<void> preloadUrl(String url) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return;
    if (_preloadedUrls.contains(cleanUrl)) return;

    _preloadedUrls.add(cleanUrl);
    // Batasi ukuran set agar tidak terlalu besar di memori
    if (_preloadedUrls.length > 20) {
      _preloadedUrls.remove(_preloadedUrls.first);
    }
  }

  /// Disposes all cached references.
  static void disposeAll() {
    _preloadedUrls.clear();
  }
}
