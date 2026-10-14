import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/recommendations_feed.dart';

class RecommendationsCache {
  RecommendationsCache(this._prefs);

  final SharedPreferences _prefs;

  String _key(String lang) => 'recommendations_cache_v1_${lang.trim().isEmpty ? 'default' : lang.trim()}';
  String get _lastKey => 'recommendations_cache_v1_last';

  RecommendationsFeed? read({required String lang}) {
    final raw = _prefs.getString(_key(lang));
    if (raw == null || raw.trim().isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return RecommendationsFeed.fromJson(decoded.cast<String, dynamic>());
  }

  RecommendationsFeed? readLast() {
    final raw = _prefs.getString(_lastKey);
    if (raw == null || raw.trim().isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return RecommendationsFeed.fromJson(decoded.cast<String, dynamic>());
  }

  Future<void> write({
    required String lang,
    required RecommendationsFeed feed,
  }) async {
    final raw = jsonEncode(feed.toJson());
    await _prefs.setString(_key(lang), raw);
    await _prefs.setString(_lastKey, raw);
  }
}

