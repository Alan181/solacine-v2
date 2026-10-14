import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/dio_provider.dart';
import '../../home/domain/home_feed.dart';

class GenreSeriesApi {
  GenreSeriesApi(this._dio);

  final Dio _dio;

  Future<List<HomeSeries>> getSeriesByCategorySlug({
    required String slug,
    required String lang,
    int page = 1,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/series',
      queryParameters: {
        'category_slug': slug,
        'page': page,
        if (lang.trim().isNotEmpty) 'lang': lang,
      },
    );
    final json = res.data ?? const <String, dynamic>{};
    final ok = json['status'] == true;
    if (!ok) {
      throw Exception((json['message'] as String?) ?? 'Failed to load series');
    }
    final data = (json['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final rawItems = data['data'];
    final list = rawItems is List ? rawItems : (rawItems is Map ? rawItems.values.toList(growable: false) : const []);
    return list.whereType<Map>().map((e) => HomeSeries.fromJson(e.cast<String, dynamic>())).toList(growable: false);
  }
}

final genreSeriesApiProvider = Provider<GenreSeriesApi>((ref) {
  return GenreSeriesApi(ref.watch(dioProvider));
});

