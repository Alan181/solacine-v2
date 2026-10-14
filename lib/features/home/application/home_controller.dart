import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bootstrap/application/bootstrap_controller.dart';
import '../../../shared/data/shared_prefs_provider.dart';
import '../data/home_api.dart';
import '../data/home_feed_cache.dart';
import '../domain/home_feed.dart';

final homeFeedProvider = FutureProvider<HomeFeed>((ref) async {
  final bootstrap = await ref.watch(appBootstrapProvider.future);
  final lang = bootstrap.localeCode;
  final prefs = await ref.watch(sharedPrefsProvider.future);
  final cache = HomeFeedCache(prefs);
  try {
    final feed = await ref.watch(homeApiProvider).getHomeFeed(lang: lang);
    final hasAny = feed.hero.isNotEmpty || feed.categories.isNotEmpty || feed.sections.any((s) => s.items.isNotEmpty);
    if (!hasAny) {
      throw Exception('Empty home feed');
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
