import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bootstrap/application/bootstrap_controller.dart';
import '../../../shared/data/shared_prefs_provider.dart';
import '../data/recommendations_api.dart';
import '../data/recommendations_cache.dart';
import '../domain/recommendations_feed.dart';

final recommendationsFeedProvider = FutureProvider<RecommendationsFeed>((ref) async {
  final bootstrap = await ref.watch(appBootstrapProvider.future);
  final lang = bootstrap.localeCode;
  final prefs = await ref.watch(sharedPrefsProvider.future);
  final cache = RecommendationsCache(prefs);

  try {
    final feed = await ref.watch(recommendationsApiProvider).getRecommendations(lang: lang, limit: 30);
    if (feed.items.isEmpty) {
      throw Exception('Empty recommendations');
    }
    await cache.write(lang: lang, feed: feed);
    return feed;
  } catch (e) {
    final cached = cache.read(lang: lang);
    if (cached != null) return cached;
    final last = cache.readLast();
    if (last != null) return last;
    rethrow;
  }
});

