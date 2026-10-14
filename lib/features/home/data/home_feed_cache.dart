import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/home_feed.dart';

class HomeFeedCache {
  HomeFeedCache(this._prefs);

  final SharedPreferences _prefs;

  String _key(String lang) => 'home_feed_cache_v1_${lang.trim().isEmpty ? 'default' : lang.trim()}';
  String get _lastKey => 'home_feed_cache_v1_last';

  HomeFeed? read({required String lang}) {
    final raw = _prefs.getString(_key(lang));
    if (raw == null || raw.trim().isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return HomeFeed.fromJson(decoded.cast<String, dynamic>());
  }

  HomeFeed? readLast() {
    final raw = _prefs.getString(_lastKey);
    if (raw == null || raw.trim().isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return HomeFeed.fromJson(decoded.cast<String, dynamic>());
  }

  Future<void> write({
    required String lang,
    required HomeFeed feed,
  }) async {
    final raw = jsonEncode(feed.toJson());
    await _prefs.setString(_key(lang), raw);
    await _prefs.setString(_lastKey, raw);
  }
}
