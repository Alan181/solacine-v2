import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bootstrap/application/bootstrap_controller.dart';
import '../../home/domain/home_feed.dart';
import '../data/genres_api.dart';

final genresSectionsProvider = FutureProvider<List<HomeSection>>((ref) async {
  final bootstrap = await ref.watch(appBootstrapProvider.future);
  final lang = bootstrap.localeCode;
  return ref.watch(genresApiProvider).getGenresSections(lang: lang);
});

