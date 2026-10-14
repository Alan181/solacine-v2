import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bootstrap/application/bootstrap_controller.dart';
import '../../home/domain/home_feed.dart';
import '../data/genre_series_api.dart';

final genreSeriesProvider = FutureProvider.autoDispose.family<List<HomeSeries>, String>((ref, slug) async {
  final bootstrap = await ref.watch(appBootstrapProvider.future);
  final lang = bootstrap.localeCode;
  return ref.watch(genreSeriesApiProvider).getSeriesByCategorySlug(slug: slug, lang: lang);
});

