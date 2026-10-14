import '../domain/home_feed.dart';

/// Cached entry holding in-memory series grid items, pagination state, and timestamp.
class SeriesGridCacheEntry {
  const SeriesGridCacheEntry({
    required this.items,
    required this.page,
    required this.hasMore,
    required this.cachedAt,
  });

  final List<HomeSeries> items;
  final int page;
  final bool hasMore;
  final DateTime cachedAt;

  /// Returns true if cached entry is older than 10 minutes.
  bool get isExpired => DateTime.now().difference(cachedAt) > const Duration(minutes: 10);
}

/// In-memory cache for series grids and rankings to avoid flickering,
/// spinners, or re-fetching when switching tabs or navigating across screens.
abstract final class SeriesGridMemoryCache {
  static final Map<String, SeriesGridCacheEntry> _cache = <String, SeriesGridCacheEntry>{};

  /// Constructs a deterministic cache key from query parameters and language.
  static String cacheKey(Map<String, dynamic> query, {String? lang}) {
    final sortedKeys = query.keys.toList()..sort();
    final parts = <String>[];
    if (lang != null && lang.trim().isNotEmpty) {
      parts.add('lang:${lang.trim()}');
    }
    for (final k in sortedKeys) {
      parts.add('$k:${query[k]}');
    }
    return parts.join('|');
  }

  /// Retrieves cached entry if present.
  static SeriesGridCacheEntry? get(Map<String, dynamic> query, {String? lang}) {
    final key = cacheKey(query, lang: lang);
    return _cache[key];
  }

  /// Saves or updates the cache entry.
  static void set({
    required Map<String, dynamic> query,
    String? lang,
    required List<HomeSeries> items,
    required int page,
    required bool hasMore,
  }) {
    final key = cacheKey(query, lang: lang);
    _cache[key] = SeriesGridCacheEntry(
      items: List.unmodifiable(items),
      page: page,
      hasMore: hasMore,
      cachedAt: DateTime.now(),
    );
  }

  /// Clears in-memory cache (e.g. on user logout or manual pull-to-refresh).
  static void clear() {
    _cache.clear();
  }
}
