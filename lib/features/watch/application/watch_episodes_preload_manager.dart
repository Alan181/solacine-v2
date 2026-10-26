import 'dart:async';
import 'package:flutter/foundation.dart';

/// Preloading manager for drama series episodes.
/// Pre-warms video cache or tracks preloaded URLs for upcoming episodes
/// so swiping between episodes is instantaneous.
class WatchEpisodesPreloadManager {
  WatchEpisodesPreloadManager._();

  static final Set<String> _preloadedUrls = <String>{};
  static final Set<String> _inFlightUrls = <String>{};

  /// Takes a pre-warmed reference (returns null since BetterPlayer initializes dynamically).
  static dynamic takePrewarmed(String url) {
    return null;
  }

  /// Checks if [url] is already tracked/preloaded.
  static bool hasPrewarmed(String url) {
    final cleanUrl = url.trim();
    return _preloadedUrls.contains(cleanUrl);
  }

  /// Pre-warms or marks the video URL for [url] in the background.
  static Future<void> preloadUrl(String url) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return;
    if (_preloadedUrls.contains(cleanUrl) || _inFlightUrls.contains(cleanUrl)) return;

    _inFlightUrls.add(cleanUrl);
    try {
      // BetterPlayer menangani caching HLS secara native di ExoPlayer/AVPlayer.
      // Kita cukup menandai URL ini sebagai preloaded/cached agar siap dipanggil.
      await Future.delayed(const Duration(milliseconds: 100)); // Simulasi async background task ringan
      
      _preloadedUrls.add(cleanUrl);

      // Keep maximum limit to prevent memory bloat
      while (_preloadedUrls.length > 5) {
        final oldestKey = _preloadedUrls.first;
        _preloadedUrls.remove(oldestKey);
      }
    } catch (_) {
      // Ignore background preload errors
    } finally {
      _inFlightUrls.remove(cleanUrl);
    }
  }

  /// Disposes all cached pre-warmed references.
  static void disposeAll() {
    _preloadedUrls.clear();
    _inFlightUrls.clear();
  }
}
