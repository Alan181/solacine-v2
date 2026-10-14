import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/dio_provider.dart';
import '../domain/recommendations_feed.dart';

class RecommendationsApi {
  RecommendationsApi(this._dio);

  final Dio _dio;

  Future<RecommendationsFeed> getRecommendations({
    required String lang,
    int limit = 30,
    String? seed,
  }) async {
    final safeLimit = limit.clamp(1, 50);
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/recommendations',
      queryParameters: {
        if (lang.trim().isNotEmpty) 'lang': lang,
        'limit': safeLimit,
        if (seed != null && seed.trim().isNotEmpty) 'seed': seed.trim(),
        '_t': DateTime.now().millisecondsSinceEpoch,
      },
    );

    final json = res.data ?? const <String, dynamic>{};
    final ok = json['status'] == true;
    if (!ok) {
      throw Exception((json['message'] as String?) ?? 'Failed to load recommendations');
    }

    final data = (json['data'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    return RecommendationsFeed.fromJson(data);
  }
}

final recommendationsApiProvider = Provider<RecommendationsApi>((ref) {
  return RecommendationsApi(ref.watch(dioProvider));
});

